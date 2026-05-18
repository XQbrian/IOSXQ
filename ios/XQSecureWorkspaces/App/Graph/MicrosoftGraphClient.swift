import Foundation
import CryptoKit

// MARK: - Response Models

struct GraphDriveItem: Decodable, Sendable {
    let id: String
    let name: String
    let size: Int64?
    let lastModifiedDateTime: String?
    let file: GraphFileFacet?
    let folder: GraphFolderFacet?
}

struct GraphFileFacet: Decodable, Sendable {
    let mimeType: String?
}

struct GraphFolderFacet: Decodable, Sendable {
    let childCount: Int?
}

struct GraphSite: Decodable, Sendable {
    let id: String
    let displayName: String?
    let webUrl: String?
}

struct GraphDrive: Decodable, Sendable {
    let id: String
    let name: String?
    let driveType: String?
}

private struct GraphListResponse<T: Decodable>: Decodable {
    let value: [T]
}

// MARK: - Error

enum GraphError: Error, LocalizedError {
    case unauthorized
    case forbidden
    case rateLimited
    case networkUnavailable
    case downloadFailed
    case invalidURL
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Graph token expired. Please sign in again."
        case .forbidden: return "Access denied by Microsoft Graph."
        case .rateLimited: return "Too many requests. Please wait and try again."
        case .networkUnavailable: return "No network connection."
        case .downloadFailed: return "File download failed."
        case .invalidURL: return "Invalid file reference."
        case .serverError(let code): return "Microsoft Graph error \(code)."
        }
    }
}

// MARK: - Client

actor MicrosoftGraphClient {

    private let baseURL = URL(string: "https://graph.microsoft.com/v1.0")!
    private let urlSession: URLSession
    private var graphToken: String

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init(graphToken: String) {
        self.graphToken = graphToken
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.urlSession = URLSession(configuration: config)
    }

    func updateToken(_ token: String) {
        graphToken = token
    }

    // MARK: - File Listing

    func listOneDriveRoot() async throws -> [GraphDriveItem] {
        let url = baseURL.appendingPathComponent("me/drive/root/children")
        return try await getList(url: url, params: ["$top": "200", "$select": "id,name,size,lastModifiedDateTime,file,folder"])
    }

    func listSharePointDriveRoot(driveId: String) async throws -> [GraphDriveItem] {
        let url = baseURL.appendingPathComponent("drives/\(driveId)/root/children")
        return try await getList(url: url, params: ["$top": "200", "$select": "id,name,size,lastModifiedDateTime,file,folder"])
    }

    func listSites() async throws -> [GraphSite] {
        let url = baseURL.appendingPathComponent("sites")
        return try await getList(url: url, params: ["search": "*", "$top": "20", "$select": "id,displayName,webUrl"])
    }

    func listSiteDrives(siteId: String) async throws -> [GraphDrive] {
        let url = baseURL.appendingPathComponent("sites/\(siteId)/drives")
        return try await getList(url: url, params: ["$select": "id,name,driveType"])
    }

    // MARK: - Download

    /// Downloads raw file bytes. encryptedKeyId format:
    ///   "{driveId}:{itemId}" → /drives/{driveId}/items/{itemId}/content
    ///   "{itemId}"           → /me/drive/items/{itemId}/content
    func downloadFileContent(encryptedKeyId: String) async throws -> Data {
        let parts = encryptedKeyId.split(separator: ":", maxSplits: 1).map(String.init)
        let contentPath: String
        if parts.count == 2 {
            contentPath = "drives/\(parts[0])/items/\(parts[1])/content"
        } else {
            contentPath = "me/drive/items/\(encryptedKeyId)/content"
        }
        let url = baseURL.appendingPathComponent(contentPath)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(graphToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GraphError.downloadFailed }
        switch http.statusCode {
        case 200...299: return data
        case 401: throw GraphError.unauthorized
        case 403: throw GraphError.forbidden
        case 429: throw GraphError.rateLimited
        default: throw GraphError.serverError(http.statusCode)
        }
    }

    // MARK: - Upload

    /// Simple upload (≤4 MB). Graph returns a DriveItem JSON on 200/201.
    func uploadFileContent(data: Data, name: String, mimeType: String) async throws -> GraphDriveItem {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        guard let url = URL(string: "\(baseURL.absoluteString)/me/drive/root:/\(encodedName):/content")
        else { throw GraphError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(graphToken)", forHTTPHeaderField: "Authorization")
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response): (Data, URLResponse)
        do { (responseData, response) = try await urlSession.data(for: request) }
        catch { throw GraphError.networkUnavailable }

        guard let http = response as? HTTPURLResponse else { throw GraphError.serverError(0) }
        switch http.statusCode {
        case 200, 201:
            return try JSONDecoder().decode(GraphDriveItem.self, from: responseData)
        case 401: throw GraphError.unauthorized
        case 403: throw GraphError.forbidden
        case 429: throw GraphError.rateLimited
        default: throw GraphError.serverError(http.statusCode)
        }
    }

    // MARK: - Helpers

    private func getList<T: Decodable>(url: URL, params: [String: String] = [:]) async throws -> [T] {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let finalURL = components.url else { throw GraphError.invalidURL }

        var request = URLRequest(url: finalURL)
        request.setValue("Bearer \(graphToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw GraphError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else { throw GraphError.networkUnavailable }
        switch http.statusCode {
        case 200...299: break
        case 401: throw GraphError.unauthorized
        case 403: throw GraphError.forbidden
        case 429: throw GraphError.rateLimited
        default: throw GraphError.serverError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(GraphListResponse<T>.self, from: data)
        return decoded.value
    }

    // MARK: - Date Parsing

    static func parseDate(_ string: String?) -> Date {
        guard let s = string else { return Date() }
        return iso8601.date(from: s) ?? Date()
    }

    // MARK: - Stable UUID

    static func stableUUID(from graphId: String) -> UUID {
        let hash = SHA256.hash(data: Data(graphId.utf8))
        var bytes = Array(hash.prefix(16))
        // Set UUID version 5 bits (RFC 4122 §4.1.3)
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2],  bytes[3],
            bytes[4], bytes[5], bytes[6],  bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
