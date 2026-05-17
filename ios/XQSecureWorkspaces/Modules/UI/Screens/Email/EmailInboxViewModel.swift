import Foundation

@MainActor
final class EmailInboxViewModel: ObservableObject {

    // MARK: - Nested Types

    struct InboxSummary {
        let criticalCount: Int
        let actionCount: Int
        let fyiCount: Int
        let noiseCount: Int
        let totalRiskScore: Int

        static let empty = InboxSummary(
            criticalCount: 0,
            actionCount: 0,
            fyiCount: 0,
            noiseCount: 0,
            totalRiskScore: 0
        )
    }

    // MARK: - Published State

    @Published var emails: [SecureEmail] = []
    @Published var triagedEmails: [SecureEmail] = []
    @Published var triageResults: [UUID: EmailTriageResult] = [:]
    @Published var isTriaging: Bool = false
    @Published var inboxSummary: InboxSummary? = nil
    @Published var error: String? = nil

    // MARK: - Dependencies

    private let orchestrator: any EmailOrchestrator

    init(orchestrator: any EmailOrchestrator) {
        self.orchestrator = orchestrator
    }

    // MARK: - Public API

    func loadInbox(session: XQSession) async {
        error = nil
        // In production this would fetch from the XQ-encrypted email store.
        // Stub provides a representative inbox for prototype demonstrations.
        emails = makeSampleInbox()
    }

    func runAITriage(policy: PolicyBundle) async {
        guard !emails.isEmpty else { return }
        isTriaging = true
        defer { isTriaging = false }
        error = nil

        do {
            let session = XQSession(
                userId: "local-user",
                tenantId: "stub-tenant",
                accessToken: "",      // never persisted to disk
                expiresAt: Date(timeIntervalSinceNow: 3600),
                apiVersion: .v3
            )
            let results = try await orchestrator.autonomousTriage(
                inbox: emails,
                session: session,
                policy: policy
            )

            var resultMap: [UUID: EmailTriageResult] = [:]
            for result in results {
                resultMap[result.emailId] = result
            }
            triageResults = resultMap

            // Sort inbox to match triage ordering (critical → noise).
            triagedEmails = emails.sorted { lhs, rhs in
                let lp = resultMap[lhs.id]?.priority ?? .noise
                let rp = resultMap[rhs.id]?.priority ?? .noise
                return lp < rp
            }

            inboxSummary = buildSummary(from: results)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markRead(_ emailId: UUID) async {
        // Optimistically update local state; a real impl would sync to the XQ vault.
        if let index = emails.firstIndex(where: { $0.id == emailId }) {
            let original = emails[index]
            emails[index] = SecureEmail(
                id: original.id,
                messageId: original.messageId,
                threadId: original.threadId,
                subject: original.subject,
                senderEmail: original.senderEmail,
                senderName: original.senderName,
                recipientEmails: original.recipientEmails,
                ccEmails: original.ccEmails,
                bodyPreview: original.bodyPreview,
                encryptedPayloadId: original.encryptedPayloadId,
                sensitivity: original.sensitivity,
                receivedAt: original.receivedAt,
                isRead: true,
                hasAttachments: original.hasAttachments
            )
        }
        if let index = triagedEmails.firstIndex(where: { $0.id == emailId }) {
            let original = triagedEmails[index]
            triagedEmails[index] = SecureEmail(
                id: original.id,
                messageId: original.messageId,
                threadId: original.threadId,
                subject: original.subject,
                senderEmail: original.senderEmail,
                senderName: original.senderName,
                recipientEmails: original.recipientEmails,
                ccEmails: original.ccEmails,
                bodyPreview: original.bodyPreview,
                encryptedPayloadId: original.encryptedPayloadId,
                sensitivity: original.sensitivity,
                receivedAt: original.receivedAt,
                isRead: true,
                hasAttachments: original.hasAttachments
            )
        }
    }

    // MARK: - Private Helpers

    private func buildSummary(from results: [EmailTriageResult]) -> InboxSummary {
        let critical = results.filter { $0.priority == .critical }.count
        let action   = results.filter { $0.priority == .action }.count
        let fyi      = results.filter { $0.priority == .fyi }.count
        let noise    = results.filter { $0.priority == .noise }.count
        return InboxSummary(
            criticalCount: critical,
            actionCount: action,
            fyiCount: fyi,
            noiseCount: noise,
            totalRiskScore: 0
        )
    }

    private func makeSampleInbox() -> [SecureEmail] {
        let now = Date()
        return [
            SecureEmail(
                id: UUID(),
                messageId: "msg-001",
                threadId: "thread-001",
                subject: "Q3 Board Presentation — Review Required",
                senderEmail: "cfo@acmecorp.com",
                senderName: "Rachel Kim",
                recipientEmails: ["user@xqmsg.com"],
                ccEmails: [],
                bodyPreview: "Please review and approve the Q3 board deck before end of day Friday. This is critical for the investor call.",
                encryptedPayloadId: "enc-001",
                sensitivity: .confidential,
                receivedAt: now.addingTimeInterval(-3600),
                isRead: false,
                hasAttachments: true
            ),
            SecureEmail(
                id: UUID(),
                messageId: "msg-002",
                threadId: "thread-002",
                subject: "Patient Lab Results — URGENT",
                senderEmail: "carol.thomas@hospital.org",
                senderName: "Carol Thomas",
                recipientEmails: ["user@xqmsg.com"],
                ccEmails: [],
                bodyPreview: "I need you to immediately confirm receipt of the attached lab results. This is critically urgent, please action ASAP.",
                encryptedPayloadId: "enc-002",
                sensitivity: .restricted,
                receivedAt: now.addingTimeInterval(-7200),
                isRead: false,
                hasAttachments: true
            ),
            SecureEmail(
                id: UUID(),
                messageId: "msg-003",
                threadId: "thread-003",
                subject: "Vendor Invoice #INV-2024-0892",
                senderEmail: "billing@supplierco.net",
                senderName: "SupplierCo Billing",
                recipientEmails: ["user@xqmsg.com"],
                ccEmails: ["ap@acmecorp.com"],
                bodyPreview: "Please find attached invoice INV-2024-0892 for $42,500. Payment is due within 30 days. Kindly process at your earliest convenience.",
                encryptedPayloadId: "enc-003",
                sensitivity: .internal_,
                receivedAt: now.addingTimeInterval(-14400),
                isRead: true,
                hasAttachments: true
            ),
            SecureEmail(
                id: UUID(),
                messageId: "msg-004",
                threadId: "thread-004",
                subject: "Team Lunch This Friday?",
                senderEmail: "alex.rodriguez@acmecorp.com",
                senderName: "Alex Rodriguez",
                recipientEmails: ["user@xqmsg.com"],
                ccEmails: ["team@acmecorp.com"],
                bodyPreview: "Hey, are you free for team lunch this Friday around noon? There's a new Thai place everyone wants to try.",
                encryptedPayloadId: "enc-004",
                sensitivity: .public_,
                receivedAt: now.addingTimeInterval(-21600),
                isRead: false,
                hasAttachments: false
            ),
            SecureEmail(
                id: UUID(),
                messageId: "msg-005",
                threadId: "thread-005",
                subject: "VERIFY YOUR ACCOUNT NOW — Security Alert",
                senderEmail: "security@micros0ft-alerts.com",
                senderName: "Microsoft Security Team",
                recipientEmails: ["user@xqmsg.com"],
                ccEmails: [],
                bodyPreview: "Unusual sign-in activity detected. Verify your account immediately to avoid suspension. Click here to confirm.",
                encryptedPayloadId: "enc-005",
                sensitivity: .internal_,
                receivedAt: now.addingTimeInterval(-28800),
                isRead: false,
                hasAttachments: false
            ),
        ]
    }
}
