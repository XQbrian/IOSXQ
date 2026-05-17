import Foundation
import XQCore
import CryptoKit

// MARK: - Well-known stub file identifiers

extension UUID {
    // Stable UUID for the Q4-Financial-Report.pdf prototype scenario.
    static let q4FinancialReport = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
}

// MARK: - DataLineageTracker

public actor DataLineageTracker: DataLineageService {

    private var lineageStore: [UUID: DataLineageRecord] = [:]

    public init() {
        lineageStore[.q4FinancialReport] = Self.makeQ4FinancialReportLineage()
    }

    // MARK: - DataLineageService

    public func lineageFor(_ fileId: UUID, session: XQSession) async throws -> DataLineageRecord {
        if let existing = lineageStore[fileId] {
            return existing
        }
        let stub = DataLineageRecord(
            fileId: fileId,
            originHash: mockSHA256(input: fileId.uuidString + "origin"),
            events: [
                LineageEvent(
                    id: UUID(),
                    timestamp: Date(timeIntervalSinceNow: -30 * 24 * 3600),
                    eventType: .created,
                    actorId: session.userId,
                    description: "File created and ingested into secure vault.",
                    cryptographicProof: nil
                )
            ],
            outputFileIds: []
        )
        lineageStore[fileId] = stub
        return stub
    }

    public func recordEvent(_ event: LineageEvent, for fileId: UUID, session: XQSession) async throws {
        if let proof = event.cryptographicProof {
            // Proof must be a 64-character hex string (SHA-256).
            guard proof.count == 64, proof.allSatisfy({ $0.isHexDigit }) else {
                throw FileIntelligenceError.lineageHashMismatch
            }
        }

        if var record = lineageStore[fileId] {
            let updated = DataLineageRecord(
                fileId: record.fileId,
                originHash: record.originHash,
                events: record.events + [event],
                outputFileIds: record.outputFileIds
            )
            lineageStore[fileId] = updated
        } else {
            lineageStore[fileId] = DataLineageRecord(
                fileId: fileId,
                originHash: mockSHA256(input: fileId.uuidString + "origin"),
                events: [event],
                outputFileIds: []
            )
        }
    }

    // MARK: - Prototype Data

    private static func makeQ4FinancialReportLineage() -> DataLineageRecord {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        func date(year: Int, month: Int, day: Int, hour: Int = 9) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }

        let fileId = UUID.q4FinancialReport

        let events: [LineageEvent] = [
            LineageEvent(
                id: UUID(uuidString: "11111111-0000-0000-0000-000000000001")!,
                timestamp: date(year: 2025, month: 11, day: 4, hour: 8),
                eventType: .created,
                actorId: "jsmith@xqmsg.com",
                description: "Q4 Financial Report created by J. Smith from FY25 budget template.",
                cryptographicProof: mockSHA256Static(input: "q4-created-nov4")
            ),
            LineageEvent(
                id: UUID(uuidString: "11111111-0000-0000-0000-000000000002")!,
                timestamp: date(year: 2025, month: 11, day: 18, hour: 14),
                eventType: .modified,
                actorId: "alee@xqmsg.com",
                description: "Revised revenue projections and added EBITDA reconciliation section.",
                cryptographicProof: mockSHA256Static(input: "q4-modified-nov18")
            ),
            LineageEvent(
                id: UUID(uuidString: "11111111-0000-0000-0000-000000000003")!,
                timestamp: date(year: 2025, month: 12, day: 3, hour: 10),
                eventType: .aiScanned,
                actorId: "system@xqmsg.com",
                description: "On-device AI scan completed; 0 bytes egressed to cloud (CONFIDENTIAL sensitivity).",
                cryptographicProof: mockSHA256Static(input: "q4-aiscanned-dec3")
            ),
            LineageEvent(
                id: UUID(uuidString: "11111111-0000-0000-0000-000000000004")!,
                timestamp: date(year: 2025, month: 12, day: 3, hour: 10),
                eventType: .classified,
                actorId: "system@xqmsg.com",
                description: "Classified as CONFIDENTIAL (confidence 0.94). Applied rule: CORP-CONF-001.",
                cryptographicProof: mockSHA256Static(input: "q4-classified-dec3")
            ),
            LineageEvent(
                id: UUID(uuidString: "11111111-0000-0000-0000-000000000005")!,
                timestamp: Date(),
                eventType: .shareBlocked,
                actorId: "bwane@xqmsg.com",
                description: "Attempted external share to vendor blocked by policy CORP-CONF-001: external sharing prohibited.",
                cryptographicProof: nil
            ),
        ]

        return DataLineageRecord(
            fileId: fileId,
            originHash: mockSHA256Static(input: "q4-financial-report-origin-2025"),
            events: events,
            outputFileIds: []
        )
    }

    // MARK: - Hash Helpers

    // Deterministic mock SHA-256: computes a real SHA-256 over the UTF-8 input.
    private static func mockSHA256Static(input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func mockSHA256(input: String) -> String {
        Self.mockSHA256Static(input: input)
    }
}
