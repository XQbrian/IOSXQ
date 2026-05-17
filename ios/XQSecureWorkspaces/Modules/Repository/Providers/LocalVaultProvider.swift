import Foundation

actor LocalVaultProvider: RepositoryProvider {

    let source: RepositorySource = .localVault
    let isAvailableOffline: Bool = true

    private let fileStore: SecureFileStore
    private let xqAPI: any XQSecureAPI
    private var metadataCache: [UUID: SecureFile] = [:]

    init(fileStore: SecureFileStore, xqAPI: any XQSecureAPI) {
        self.fileStore = fileStore
        self.xqAPI = xqAPI
    }

    // MARK: - RepositoryProvider

    func listFiles(path: String) async throws -> [SecureFile] {
        Array(metadataCache.values).sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func fetchFile(_ file: SecureFile) async throws -> Data {
        // Build the URL using the file's id as the stored file name.
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let fileURL = appSupport
            .appendingPathComponent("XQVault", isDirectory: true)
            .appendingPathComponent(file.id.uuidString)

        let payload = try await fileStore.read(from: fileURL)
        // Plaintext never touches disk; decryption happens entirely in memory.
        let session = try currentSession()
        return try await xqAPI.decryptFile(payload, session: session)
    }

    func uploadFile(data: Data, name: String, path: String, session: XQSession) async throws -> SecureFile {
        // Encrypt before any persistence; plaintext never reaches disk.
        let payload = try await xqAPI.encryptFile(data: data, session: session)

        let fileId = UUID()
        _ = try await fileStore.write(payload: payload, fileName: fileId.uuidString)

        let mime = mimeType(for: name)
        let file = SecureFile(
            id: fileId,
            name: name,
            mimeType: mime,
            sizeBytes: Int64(data.count),
            sensitivity: .internal_,
            encryptedKeyId: payload.keyId,
            sourceProvider: .localVault,
            modifiedAt: Date(),
            riskScore: nil
        )
        metadataCache[fileId] = file
        return file
    }

    func deleteFile(_ file: SecureFile, session: XQSession) async throws {
        metadataCache.removeValue(forKey: file.id)

        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let fileURL = appSupport
            .appendingPathComponent("XQVault", isDirectory: true)
            .appendingPathComponent(file.id.uuidString)

        try await fileStore.delete(at: fileURL)
    }

    func deltaSync(since cursor: SyncCursor?) async throws -> DeltaSyncResult {
        // Local vault has no remote counterpart; there is nothing to diff.
        let nextCursor = SyncCursor(
            token: UUID().uuidString,
            fetchedAt: Date(),
            provider: .localVault
        )
        return DeltaSyncResult(added: [], modified: [], deleted: [], nextCursor: nextCursor)
    }

    // MARK: - Private helpers

    /// Infers MIME type from the file extension. Production callers may supply
    /// an explicit type instead.
    private func mimeType(for name: String) -> String {
        switch URL(fileURLWithPath: name).pathExtension.lowercased() {
        case "pdf":  return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        default:     return "application/octet-stream"
        }
    }

    /// Placeholder: in production the caller passes a live XQSession; this
    /// actor does not own session state, so callers that need a session for
    /// fetchFile must provide one. This is a design smell that will be resolved
    /// when fetchFile signature is updated to accept XQSession.
    private func currentSession() throws -> XQSession {
        // TODO: accept XQSession as a parameter in fetchFile once the protocol
        // is updated in Phase 5. For now throw to surface the gap at runtime.
        throw RepositoryError.authenticationRequired
    }
}
