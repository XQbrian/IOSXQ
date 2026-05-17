import Foundation
import XQCore
import XQRepository

/// Provides rich, deterministic mock data for the FileBrowser screen during
/// development and demos. Conforms to `RepositoryProvider` so it can be swapped
/// in seamlessly via dependency injection.
///
/// All UUIDs are stable across launches so SwiftUI identity stays consistent
/// and snapshot/UI tests remain reproducible. A short artificial latency is
/// added to simulate a network call and exercise loading states.
final class SampleDataRepository: RepositoryProvider, @unchecked Sendable {

    var source: RepositorySource { .sharePoint }
    var isAvailableOffline: Bool { true }

    // MARK: - Init

    init() {}

    // MARK: - RepositoryProvider

    func listFiles(path: String) async throws -> [SecureFile] {
        // Simulate a 400ms fetch so the UI shows its loading skeleton.
        try? await Task.sleep(nanoseconds: 400_000_000)
        return Self.sampleFiles
    }

    func fetchFile(_ file: SecureFile) async throws -> Data {
        // Decryption is handled upstream by the AI orchestrator / FileViewer.
        Data()
    }

    func uploadFile(data: Data, name: String, path: String, session: XQSession) async throws -> SecureFile {
        // Sample data is read-only; uploads require a real authenticated session.
        throw RepositoryError.authenticationRequired
    }

    func deleteFile(_ file: SecureFile, session: XQSession) async throws {
        throw RepositoryError.authenticationRequired
    }

    func deltaSync(since cursor: SyncCursor?) async throws -> DeltaSyncResult {
        DeltaSyncResult(
            added: [],
            modified: [],
            deleted: [],
            nextCursor: SyncCursor(
                token: "sample-cursor-\(UUID().uuidString.prefix(8))",
                fetchedAt: Date(),
                provider: .sharePoint
            )
        )
    }

    // MARK: - Sample Data

    /// Helper that builds a deterministic UUID from a single hex digit (1-10).
    private static func uuid(_ index: Int) -> UUID {
        let hex = String(format: "%012d", index)
        return UUID(uuidString: "11111111-0000-0000-0000-\(hex)")!
    }

    /// Returns a date `offset` seconds in the past, relative to `now`.
    private static func ago(_ offset: TimeInterval, from now: Date = Date()) -> Date {
        now.addingTimeInterval(-offset)
    }

    static let sampleFiles: [SecureFile] = {
        let now = Date()
        let hour: TimeInterval = 3_600
        let day: TimeInterval = 86_400

        return [
            SecureFile(
                id: uuid(1),
                name: "Q4-Financial-Report.pdf",
                mimeType: "application/pdf",
                sizeBytes: 2_516_582,            // 2.4 MB
                sensitivity: .restricted,
                encryptedKeyId: "key-q4-fin-001",
                sourceProvider: .sharePoint,
                modifiedAt: ago(2 * hour, from: now),
                riskScore: 87
            ),
            SecureFile(
                id: uuid(2),
                name: "Employee-Handbook-2026.docx",
                mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                sizeBytes: 867_328,              // 847 KB
                sensitivity: .internal_,
                encryptedKeyId: "key-handbook-002",
                sourceProvider: .sharePoint,
                modifiedAt: ago(1 * day + 4 * hour, from: now),
                riskScore: 12
            ),
            SecureFile(
                id: uuid(3),
                name: "Client-Contract-Acme.pdf",
                mimeType: "application/pdf",
                sizeBytes: 1_258_291,            // 1.2 MB
                sensitivity: .confidential,
                encryptedKeyId: "key-contract-003",
                sourceProvider: .sharePoint,
                modifiedAt: ago(3 * day, from: now),
                riskScore: 65
            ),
            SecureFile(
                id: uuid(4),
                name: "Product-Roadmap-2026.pptx",
                mimeType: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                sizeBytes: 4_928_307,            // 4.7 MB
                sensitivity: .confidential,
                encryptedKeyId: "key-roadmap-004",
                sourceProvider: .xqVault,
                modifiedAt: ago(5 * day, from: now),
                riskScore: 45
            ),
            SecureFile(
                id: uuid(5),
                name: "Budget-2026-Final.xlsx",
                mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                sizeBytes: 921_600,              // 900 KB
                sensitivity: .restricted,
                encryptedKeyId: "key-budget-005",
                sourceProvider: .sharePoint,
                modifiedAt: ago(1 * day + 2 * hour, from: now),
                riskScore: 78
            ),
            SecureFile(
                id: uuid(6),
                name: "Press-Release-Draft.docx",
                mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                sizeBytes: 156_672,              // 153 KB
                sensitivity: .public_,
                encryptedKeyId: "key-press-006",
                sourceProvider: .xqVault,
                modifiedAt: ago(1 * hour, from: now),
                riskScore: 8
            ),
            SecureFile(
                id: uuid(7),
                name: "Patient-Records-Q1.pdf",
                mimeType: "application/pdf",
                sizeBytes: 3_355_443,            // 3.2 MB
                sensitivity: .restricted,
                encryptedKeyId: "key-patient-007",
                sourceProvider: .localVault,
                modifiedAt: ago(7 * day, from: now),
                riskScore: 94
            ),
            SecureFile(
                id: uuid(8),
                name: "Meeting-Notes-BoardQ4.docx",
                mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                sizeBytes: 234_496,              // 229 KB
                sensitivity: .internal_,
                encryptedKeyId: "key-board-008",
                sourceProvider: .xqVault,
                modifiedAt: ago(2 * day, from: now),
                riskScore: 15
            ),
            SecureFile(
                id: uuid(9),
                name: "Security-Audit-2025.pdf",
                mimeType: "application/pdf",
                sizeBytes: 1_887_437,            // 1.8 MB
                sensitivity: .confidential,
                encryptedKeyId: "key-audit-009",
                sourceProvider: .xqVault,
                modifiedAt: ago(14 * day, from: now),
                riskScore: 52
            ),
            SecureFile(
                id: uuid(10),
                name: "Sales-Pipeline-Q1.xlsx",
                mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                sizeBytes: 672_768,              // 657 KB
                sensitivity: .confidential,
                encryptedKeyId: "key-sales-010",
                sourceProvider: .sharePoint,
                modifiedAt: ago(6 * hour, from: now),
                riskScore: 38
            )
        ]
    }()
}
