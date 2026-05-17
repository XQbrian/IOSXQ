import Foundation

public protocol RepositoryProvider: Sendable {
    var source: RepositorySource { get }
    var isAvailableOffline: Bool { get }

    func listFiles(path: String) async throws -> [SecureFile]
    func fetchFile(_ file: SecureFile) async throws -> Data
    func uploadFile(data: Data, name: String, path: String, session: XQSession) async throws -> SecureFile
    func deleteFile(_ file: SecureFile, session: XQSession) async throws
    func deltaSync(since cursor: SyncCursor?) async throws -> DeltaSyncResult
}

public struct SyncCursor: Codable {
    public let token: String
    public let fetchedAt: Date
    public let provider: RepositorySource

    public init(token: String, fetchedAt: Date, provider: RepositorySource) {
        self.token = token
        self.fetchedAt = fetchedAt
        self.provider = provider
    }
}

public struct DeltaSyncResult {
    public let added: [SecureFile]
    public let modified: [SecureFile]
    public let deleted: [UUID]
    public let nextCursor: SyncCursor

    public init(added: [SecureFile], modified: [SecureFile], deleted: [UUID], nextCursor: SyncCursor) {
        self.added = added
        self.modified = modified
        self.deleted = deleted
        self.nextCursor = nextCursor
    }
}

public enum RepositoryError: Error {
    case authenticationRequired
    case fileNotFound(id: UUID)
    case quotaExceeded
    case conflictDetected(localVersion: SecureFile, remoteVersion: SecureFile)
    case encryptionRequiredBeforeUpload
    case offlineOperationQueued(operationId: UUID)
}
