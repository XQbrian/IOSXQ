import Foundation
import XQCore

// Real XQ Message v2 Subscription API.
// Base URL: https://subscription.xqmsg.net/v2
// Auth header: api-key: <api_key>
actor XQSubscriptionClient {

    private let apiKey: String
    private let baseURL: URL
    private let urlSession: URLSession

    init(apiKey: String, baseURL: URL) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: config)
    }

    // Step 1: Send OTP to the subscriber's email.
    // POST /authorize  { "user": "email@domain.com", "notifications": 0 }
    func authorize(email: String) async throws {
        struct Body: Encodable { let user: String; let notifications: Int }
        try await post(path: "/authorize", body: Body(user: email, notifications: 0))
    }

    // Step 2: Validate the OTP pin. Returns the XQ access token as plain text.
    // GET /codevalidation/<pin>
    func validatePin(_ pin: String) async throws -> String {
        let url = baseURL.appendingPathComponent("/codevalidation/\(pin)")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "api-key")

        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw XQAPIError.networkUnavailable }
        switch http.statusCode {
        case 200...299:
            guard let token = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !token.isEmpty else {
                throw XQAPIError.unauthenticated
            }
            return token
        case 401: throw XQAPIError.unauthenticated
        default:
            throw XQAPIError.serverError(statusCode: http.statusCode, message: "Pin validation failed")
        }
    }

    // Fetch subscriber profile — resolves userId/tenantId after token is acquired.
    // GET /subscriber   Authorization: <token>
    func fetchSubscriber(token: String) async throws -> SubscriberProfile {
        let url = baseURL.appendingPathComponent("/subscriber")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "api-key")
        req.setValue(token, forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw XQAPIError.unauthenticated
        }
        return try JSONDecoder.xqSub.decode(SubscriberProfile.self, from: data)
    }

    // Revoke current token on sign-out.
    // DELETE /revoke   Authorization: <token>
    func revokeToken(_ token: String) async throws {
        let url = baseURL.appendingPathComponent("/revoke")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue(apiKey, forHTTPHeaderField: "api-key")
        req.setValue(token, forHTTPHeaderField: "Authorization")
        _ = try? await urlSession.data(for: req)
    }

    // MARK: - Helpers

    private func post<B: Encodable>(path: String, body: B) async throws {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "api-key")
        req.httpBody = try JSONEncoder.xqSub.encode(body)

        let (_, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw XQAPIError.networkUnavailable }
        switch http.statusCode {
        case 200...299: return
        case 401: throw XQAPIError.unauthenticated
        case 429: throw XQAPIError.rateLimited(retryAfter: 60)
        default:
            throw XQAPIError.serverError(statusCode: http.statusCode, message: "Request failed")
        }
    }
}

struct SubscriberProfile: Sendable, Decodable {
    let id: String
    let email: String

    enum CodingKeys: String, CodingKey { case id, sub }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id  = try c.decode(String.self, forKey: .id)
        email = try c.decode(String.self, forKey: .sub)
    }
}

private extension JSONEncoder {
    static let xqSub: JSONEncoder = {
        let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; return e
    }()
}

private extension JSONDecoder {
    static let xqSub: JSONDecoder = {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }()
}
