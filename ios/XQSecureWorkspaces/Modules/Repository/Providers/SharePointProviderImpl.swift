import Foundation

actor SharePointProviderImpl: SharePointProvider {

    let source: RepositorySource = .sharePoint
    let isAvailableOffline: Bool = false

    private let gateway: XQAPIGateway
    private let xqAPI: any XQSecureAPI
    private var sharePointSession: SharePointSession?

    init(gateway: XQAPIGateway, xqAPI: any XQSecureAPI) {
        self.gateway = gateway
        self.xqAPI = xqAPI
    }

    // MARK: - SharePointProvider

    func authenticate(tenantId: String, clientId: String) async throws -> SharePointSession {
        struct AuthBody: Encodable { let tenantId: String; let clientId: String }
        let body = AuthBody(tenantId: tenantId, clientId: clientId)
        let session: SharePointSession = try await gateway.post(
            path: "sharepoint/auth",
            body: body
        )
        self.sharePointSession = session
        return session
    }

    func listSites() async throws -> [SharePointSite] {
        guard sharePointSession != nil else {
            throw RepositoryError.authenticationRequired
        }
        return try await gateway.get(path: "graph/v1.0/sites")
    }

    func fetchDriveItems(siteId: String, driveId: String, path: String) async throws -> [SecureFile] {
        guard sharePointSession != nil else {
            throw RepositoryError.authenticationRequired
        }
        let endpoint = "graph/v1.0/sites/\(siteId)/drives/\(driveId)/root:\(path):/children"
        struct DriveItemsResponse: Decodable { let value: [GraphDriveItem] }
        let response: DriveItemsResponse = try await gateway.get(path: endpoint)
        return response.value.map { $0.toSecureFile(sourceProvider: .sharePoint) }
    }

    // MARK: - RepositoryProvider

    func listFiles(path: String) async throws -> [SecureFile] {
        // Uses empty-string placeholders; callers should prefer fetchDriveItems
        // directly once siteId and driveId are resolved for the tenant.
        try await fetchDriveItems(siteId: "", driveId: "", path: path)
    }

    func fetchFile(_ file: SecureFile) async throws -> Data {
        // Downloads raw bytes from SharePoint via the Graph content endpoint.
        // PRODUCTION NOTE: In a full XQ deployment the file stored in SharePoint
        // will be an EncryptedPayload blob. Callers must decrypt it via
        // xqAPI.decryptFile before returning plaintext to the UI layer.
        // The current implementation returns raw bytes as a stub; no plaintext
        // is cached to disk.
        let endpoint = "graph/v1.0/me/drive/items/\(file.id)/content"
        let data: Data = try await gateway.get(path: endpoint)
        return data
    }

    func uploadFile(data: Data, name: String, path: String, session: XQSession) async throws -> SecureFile {
        // Encrypt before transit; plaintext never leaves the device unprotected.
        let payload = try await xqAPI.encryptFile(data: data, session: session)
        let encryptedBlob = payload.iv + payload.authTag + payload.ciphertext

        struct PutBody: Encodable { let content: Data }
        let endpoint = "graph/v1.0/me/drive/root:\(path)/\(name):/content"
        let body = PutBody(content: encryptedBlob)
        let _: EmptyResponse = try await gateway.post(path: endpoint, body: body)

        return SecureFile(
            id: UUID(),
            name: name,
            mimeType: mimeType(for: name),
            sizeBytes: Int64(data.count),
            sensitivity: .internal_,
            encryptedKeyId: payload.keyId,
            sourceProvider: .sharePoint,
            modifiedAt: Date(),
            riskScore: nil
        )
    }

    func deleteFile(_ file: SecureFile, session: XQSession) async throws {
        struct DeleteBody: Encodable {}
        let endpoint = "graph/v1.0/me/drive/items/\(file.id)"
        let _: EmptyResponse = try await gateway.post(path: endpoint, body: DeleteBody())
        // Note: XQAPIGateway exposes post/get helpers. A DELETE verb helper
        // will be added in Phase 5; until then this post stands as a placeholder.
    }

    func deltaSync(since cursor: SyncCursor?) async throws -> DeltaSyncResult {
        let endpoint: String
        if let cursor {
            endpoint = "graph/v1.0/me/drive/root/delta?token=\(cursor.token)"
        } else {
            endpoint = "graph/v1.0/me/drive/root/delta"
        }
        let response: GraphDeltaResponse = try await gateway.get(path: endpoint)

        let added = response.value.map { $0.toSecureFile(sourceProvider: .sharePoint) }
        let nextToken = response.odataNextLink ?? response.odeltaLink ?? UUID().uuidString
        let nextCursor = SyncCursor(
            token: nextToken,
            fetchedAt: Date(),
            provider: .sharePoint
        )
        // Delta response does not distinguish added vs. modified vs. deleted in
        // this stub; production should inspect the 'deleted' facet on each item.
        return DeltaSyncResult(added: added, modified: [], deleted: [], nextCursor: nextCursor)
    }

    // MARK: - Private helpers

    private func mimeType(for name: String) -> String {
        switch URL(fileURLWithPath: name).pathExtension.lowercased() {
        case "pdf":  return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        default:     return "application/octet-stream"
        }
    }
}

// MARK: - Graph API response types (private to this file)

private struct GraphDriveItem: Decodable {
    let id: String
    let name: String
    let size: Int64?
    let lastModifiedDateTime: Date

    func toSecureFile(sourceProvider: RepositorySource) -> SecureFile {
        SecureFile(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            mimeType: mimeType(for: name),
            sizeBytes: size ?? 0,
            // Real sensitivity classification happens at AI scan time.
            sensitivity: .internal_,
            encryptedKeyId: id,
            sourceProvider: sourceProvider,
            modifiedAt: lastModifiedDateTime,
            riskScore: nil
        )
    }

    private func mimeType(for name: String) -> String {
        switch URL(fileURLWithPath: name).pathExtension.lowercased() {
        case "pdf":  return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        default:     return "application/octet-stream"
        }
    }
}

private struct GraphDeltaResponse: Decodable {
    let value: [GraphDriveItem]
    /// "@odata.deltaLink" — present on the final page of a delta response.
    let odeltaLink: String?
    /// "@odata.nextLink" — present when more pages remain.
    let odataNextLink: String?

    private enum CodingKeys: String, CodingKey {
        case value
        case odeltaLink   = "@odata.deltaLink"
        case odataNextLink = "@odata.nextLink"
    }
}

/// Used where the gateway requires a Decodable return type but the HTTP body
/// carries no meaningful payload (e.g. 204 No Content).
private struct EmptyResponse: Decodable {}

// SharePointSession and SharePointSite need to be Decodable for gateway use.
// These extensions live here so the Core protocol files stay pure.
extension SharePointSession: Decodable {
    private enum CodingKeys: String, CodingKey {
        case accessToken, refreshToken, expiresAt, tenantId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accessToken  = try c.decode(String.self, forKey: .accessToken)
        refreshToken = try c.decode(String.self, forKey: .refreshToken)
        expiresAt    = try c.decode(Date.self,   forKey: .expiresAt)
        tenantId     = try c.decode(String.self, forKey: .tenantId)
    }
}

extension SharePointSite: Decodable {
    private enum CodingKeys: String, CodingKey { case id, displayName, webUrl }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        webUrl      = try c.decode(String.self, forKey: .webUrl)
    }
}

// Data needs to be Decodable from a raw-bytes gateway response.
// XQAPIGateway.get returns T: Decodable; for raw Data we decode the base64
// representation the Graph API returns for binary content endpoints.
extension Data: @retroactive Decodable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        // Graph /content returns base64-encoded bytes in JSON context.
        let b64 = try c.decode(String.self)
        guard let d = Data(base64Encoded: b64) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid base64")
        }
        self = d
    }
}
