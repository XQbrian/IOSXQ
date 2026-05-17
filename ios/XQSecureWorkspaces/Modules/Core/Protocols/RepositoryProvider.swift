import Foundation

protocol RepositoryProvider: Sendable {
    var source: RepositorySource { get }
    var isAvailableOffline: Bool { get }

    func listFiles(path: String) async throws -> [SecureFile]
    func fetchFile(_ file: SecureFile) async throws -> Data
    func uploadFile(data: Data, name: String, path: String, session: XQSession) async throws -> SecureFile
    func deleteFile(_ file: SecureFile, session: XQSession) async throws
    func deltaSync(since cursor: SyncCursor?) async throws -> DeltaSyncResult
}

struct SyncCursor: Codable {
    let token: String
    let fetchedAt: Date
    let provider: RepositorySource
}

struct DeltaSyncResult {
    let added: [SecureFile]
    let modified: [SecureFile]
    let deleted: [UUID]
    let nextCursor: SyncCursor
}

enum RepositoryError: Error {
    case authenticationRequired
    case fileNotFound(id: UUID)
    case quotaExceeded
    case conflictDetected(localVersion: SecureFile, remoteVersion: SecureFile)
    case encryptionRequiredBeforeUpload
    case offlineOperationQueued(operationId: UUID)
}
