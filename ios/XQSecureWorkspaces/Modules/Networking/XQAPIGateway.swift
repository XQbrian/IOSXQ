import Foundation

actor XQAPIGateway {

    private let baseURL: URL
    private let pinner: any CertificatePinner
    private let session: URLSession
    private(set) var negotiatedVersion: XQAPIVersion = .v1

    init(baseURL: URL, pinner: any CertificatePinner) {
        self.baseURL = baseURL
        self.pinner = pinner
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        // URLSession delegate is set after init to allow self-reference.
        self.session = URLSession(configuration: config)
    }

    func negotiateVersion() async throws {
        struct CapabilityResponse: Decodable { let maxVersion: String }
        let response: CapabilityResponse = try await get(path: "v1/capabilities")
        negotiatedVersion = XQAPIVersion(rawValue: response.maxVersion) ?? .v1
    }

    // MARK: - Internal request helpers

    func get<T: Decodable>(path: String, session xqSession: XQSession? = nil) async throws -> T {
        let req = try buildRequest(method: "GET", path: path, body: nil as Data?, xqSession: xqSession)
        return try await execute(req)
    }

    func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        session xqSession: XQSession? = nil
    ) async throws -> Response {
        let bodyData = try JSONEncoder.xq.encode(body)
        let req = try buildRequest(method: "POST", path: path, body: bodyData, xqSession: xqSession)
        return try await execute(req)
    }

    private func buildRequest<Body: DataProtocol>(
        method: String,
        path: String,
        body: Body?,
        xqSession: XQSession?
    ) throws -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("XQ-iOS/1.0", forHTTPHeaderField: "User-Agent")
        if let token = xqSession?.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body { req.httpBody = Data(body) }
        return req
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw XQAPIError.networkUnavailable }
        switch http.statusCode {
        case 200...299:
            return try JSONDecoder.xq.decode(T.self, from: data)
        case 401:
            throw XQAPIError.unauthenticated
        case 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init) ?? 60
            throw XQAPIError.rateLimited(retryAfter: retry)
        default:
            let msg = (try? JSONDecoder.xq.decode(APIErrorBody.self, from: data))?.message ?? "Unknown"
            throw XQAPIError.serverError(statusCode: http.statusCode, message: msg)
        }
    }
}

private struct APIErrorBody: Decodable { let message: String }

extension JSONEncoder {
    static let xq: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
}

extension JSONDecoder {
    static let xq: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
