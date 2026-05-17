import Foundation

// MARK: - OfflineOperation

/// Represents a mutation that could not be sent to the remote provider because
/// the device was offline. Operations are executed in order when connectivity
/// is restored via drainQueue(session:).
enum OfflineOperation: Identifiable {
    case upload(id: UUID, data: Data, name: String, path: String, provider: RepositorySource)
    case delete(id: UUID, fileId: UUID, provider: RepositorySource)

    var id: UUID {
        switch self {
        case .upload(let id, _, _, _, _): return id
        case .delete(let id, _, _):       return id
        }
    }
}

// MARK: - SyncEngine

/// Coordinates delta synchronisation across all registered repository providers
/// and manages an in-memory queue of offline operations that are drained once
/// connectivity returns.
actor SyncEngine {

    private var providers: [any RepositoryProvider] = []
    private var operationQueue: [OfflineOperation] = []
    private var syncCursors: [RepositorySource: SyncCursor] = [:]
    private let xqAPI: any XQSecureAPI

    init(xqAPI: any XQSecureAPI) {
        self.xqAPI = xqAPI
    }

    // MARK: - Provider registration

    func register(provider: any RepositoryProvider) {
        providers.append(provider)
    }

    // MARK: - Offline queue

    func enqueueUpload(data: Data, name: String, path: String, provider: RepositorySource) {
        let op = OfflineOperation.upload(
            id: UUID(),
            data: data,
            name: name,
            path: path,
            provider: provider
        )
        operationQueue.append(op)
    }

    func enqueueDelete(fileId: UUID, provider: RepositorySource) {
        let op = OfflineOperation.delete(
            id: UUID(),
            fileId: fileId,
            provider: provider
        )
        operationQueue.append(op)
    }

    /// Drains the offline queue by executing each queued operation against the
    /// matching provider. Successfully executed operations are removed; failed
    /// operations remain in the queue for the next drain attempt.
    func drainQueue(session: XQSession) async {
        var remaining: [OfflineOperation] = []

        for operation in operationQueue {
            do {
                switch operation {
                case .upload(_, let data, let name, let path, let providerSource):
                    guard let provider = providers.first(where: { $0.source == providerSource }) else {
                        remaining.append(operation)
                        continue
                    }
                    _ = try await provider.uploadFile(data: data, name: name, path: path, session: session)

                case .delete(_, let fileId, let providerSource):
                    guard let provider = providers.first(where: { $0.source == providerSource }) else {
                        remaining.append(operation)
                        continue
                    }
                    // Construct a minimal SecureFile to satisfy the protocol signature.
                    // Production should persist full metadata alongside the operation.
                    let placeholder = SecureFile(
                        id: fileId,
                        name: "",
                        mimeType: "application/octet-stream",
                        sizeBytes: 0,
                        sensitivity: .internal_,
                        encryptedKeyId: "",
                        sourceProvider: providerSource,
                        modifiedAt: Date(),
                        riskScore: nil
                    )
                    try await provider.deleteFile(placeholder, session: session)
                }
            } catch {
                // Leave failed operations in the queue; they will be retried on
                // the next drainQueue call.
                remaining.append(operation)
            }
        }

        operationQueue = remaining
    }

    // MARK: - Delta sync

    /// Runs deltaSync on every registered provider, updates the stored cursors,
    /// and returns one DeltaSyncResult per provider.
    func syncAll(session: XQSession) async throws -> [DeltaSyncResult] {
        var results: [DeltaSyncResult] = []

        for provider in providers {
            let cursor = syncCursors[provider.source]
            let result = try await provider.deltaSync(since: cursor)
            syncCursors[provider.source] = result.nextCursor
            results.append(result)
        }

        return results
    }

    // MARK: - Conflict resolution

    /// Returns the file with the later modifiedAt timestamp (last-write-wins).
    ///
    /// PRODUCTION NOTE: Files classified as PHI (sensitivity == .restricted or
    /// entities containing .phi) must never be resolved automatically. Those
    /// conflicts must be surfaced to the user or a compliance officer for manual
    /// resolution to satisfy HIPAA audit requirements.
    func conflictPolicy(local: SecureFile, remote: SecureFile) -> SecureFile {
        local.modifiedAt >= remote.modifiedAt ? local : remote
    }
}
