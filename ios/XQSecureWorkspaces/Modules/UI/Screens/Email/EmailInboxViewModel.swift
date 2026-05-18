import Foundation
import XQCore
import XQEmailIntelligence
import XQPolicy

@MainActor
final class EmailInboxViewModel: ObservableObject {

    // MARK: - Nested Types

    struct InboxSummary {
        let criticalCount: Int
        let actionCount: Int
        let fyiCount: Int
        let noiseCount: Int

        static let empty = InboxSummary(criticalCount: 0, actionCount: 0, fyiCount: 0, noiseCount: 0)
    }

    enum Filter: String, CaseIterable {
        case all = "All"
        case critical = "Critical"
        case action = "Action"
        case fyi = "FYI"
    }

    // MARK: - Published State

    @Published var emails: [SecureEmail] = []
    @Published var triagedEmails: [SecureEmail] = []
    @Published var triageResults: [UUID: EmailTriageResult] = [:]
    @Published var isLoading: Bool = false
    @Published var isTriaging: Bool = false
    @Published var inboxSummary: InboxSummary? = nil
    @Published var selectedFilter: Filter = .all
    @Published var error: String? = nil

    var displayedEmails: [SecureEmail] {
        let base = triagedEmails.isEmpty ? emails : triagedEmails
        switch selectedFilter {
        case .all: return base
        case .critical: return base.filter { triageResults[$0.id]?.priority == .critical }
        case .action:   return base.filter { triageResults[$0.id]?.priority == .action }
        case .fyi:      return base.filter {
            let p = triageResults[$0.id]?.priority
            return p == .fyi || p == .noise
        }
        }
    }

    var unreadCount: Int { emails.filter { !$0.isRead }.count }

    // MARK: - Dependencies

    private let orchestrator: any EmailOrchestrator

    init(orchestrator: any EmailOrchestrator) {
        self.orchestrator = orchestrator
    }

    // MARK: - Load

    func loadInbox(session: XQSession, graphClient: MicrosoftGraphClient?) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        if let client = graphClient {
            do {
                let messages = try await client.listMessages(top: 50)
                emails = messages.map { graphMessageToSecureEmail($0) }
                return
            } catch {
                // Graph unavailable — fall through to sample data
            }
        }
        emails = makeSampleInbox()
    }

    // MARK: - AI Triage

    func runAITriage(policy: PolicyBundle) async {
        guard !emails.isEmpty else { return }
        isTriaging = true
        defer { isTriaging = false }
        error = nil

        do {
            let session = XQSession(
                userId: "local-user",
                tenantId: "stub-tenant",
                accessToken: "",
                expiresAt: Date(timeIntervalSinceNow: 3600),
                apiVersion: .v3
            )
            let results = try await orchestrator.autonomousTriage(
                inbox: emails,
                session: session,
                policy: policy
            )

            var resultMap: [UUID: EmailTriageResult] = [:]
            for result in results { resultMap[result.emailId] = result }
            triageResults = resultMap

            triagedEmails = emails.sorted { lhs, rhs in
                let lp = resultMap[lhs.id]?.priority ?? .noise
                let rp = resultMap[rhs.id]?.priority ?? .noise
                return lp < rp
            }

            inboxSummary = InboxSummary(
                criticalCount: results.filter { $0.priority == .critical }.count,
                actionCount:   results.filter { $0.priority == .action }.count,
                fyiCount:      results.filter { $0.priority == .fyi }.count,
                noiseCount:    results.filter { $0.priority == .noise }.count
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markRead(_ emailId: UUID) {
        func updated(_ e: SecureEmail) -> SecureEmail {
            SecureEmail(id: e.id, messageId: e.messageId, threadId: e.threadId,
                        subject: e.subject, senderEmail: e.senderEmail, senderName: e.senderName,
                        recipientEmails: e.recipientEmails, ccEmails: e.ccEmails,
                        bodyPreview: e.bodyPreview, encryptedPayloadId: e.encryptedPayloadId,
                        sensitivity: e.sensitivity, receivedAt: e.receivedAt,
                        isRead: true, hasAttachments: e.hasAttachments)
        }
        if let i = emails.firstIndex(where: { $0.id == emailId }) { emails[i] = updated(emails[i]) }
        if let i = triagedEmails.firstIndex(where: { $0.id == emailId }) { triagedEmails[i] = updated(triagedEmails[i]) }
    }

    // MARK: - Graph → Model

    private func graphMessageToSecureEmail(_ msg: GraphMessage) -> SecureEmail {
        let stableId = MicrosoftGraphClient.stableUUID(from: msg.id)
        let senderAddr = msg.from?.emailAddress?.address ?? "unknown@unknown.com"
        let senderName = msg.from?.emailAddress?.name ?? senderAddr
        let sensitivity: SensitivityLevel = {
            switch msg.sensitivity?.lowercased() {
            case "confidential": return .restricted
            case "private":      return .confidential
            case "personal":     return .public_
            default:             return .internal_
            }
        }()
        return SecureEmail(
            id: stableId,
            messageId: msg.id,
            threadId: msg.conversationId ?? msg.id,
            subject: msg.subject ?? "(No Subject)",
            senderEmail: senderAddr,
            senderName: senderName,
            recipientEmails: msg.toRecipients?.compactMap { $0.emailAddress?.address } ?? [],
            ccEmails: msg.ccRecipients?.compactMap { $0.emailAddress?.address } ?? [],
            bodyPreview: msg.bodyPreview ?? "",
            encryptedPayloadId: msg.id,
            sensitivity: sensitivity,
            receivedAt: MicrosoftGraphClient.parseDate(msg.receivedDateTime),
            isRead: msg.isRead ?? true,
            hasAttachments: msg.hasAttachments ?? false
        )
    }

    // MARK: - Sample fallback

    private func makeSampleInbox() -> [SecureEmail] {
        let now = Date()
        return [
            SecureEmail(id: UUID(), messageId: "msg-001", threadId: "thread-001",
                        subject: "Q3 Board Presentation — Review Required",
                        senderEmail: "cfo@acmecorp.com", senderName: "Rachel Kim",
                        recipientEmails: ["user@xqmsg.com"], ccEmails: [],
                        bodyPreview: "Please review and approve the Q3 board deck before end of day Friday. This is critical for the investor call.",
                        encryptedPayloadId: "enc-001", sensitivity: .confidential,
                        receivedAt: now.addingTimeInterval(-3600), isRead: false, hasAttachments: true),
            SecureEmail(id: UUID(), messageId: "msg-002", threadId: "thread-002",
                        subject: "Patient Lab Results — URGENT",
                        senderEmail: "carol.thomas@hospital.org", senderName: "Carol Thomas",
                        recipientEmails: ["user@xqmsg.com"], ccEmails: [],
                        bodyPreview: "I need you to immediately confirm receipt of the attached lab results. This is critically urgent, please action ASAP.",
                        encryptedPayloadId: "enc-002", sensitivity: .restricted,
                        receivedAt: now.addingTimeInterval(-7200), isRead: false, hasAttachments: true),
            SecureEmail(id: UUID(), messageId: "msg-003", threadId: "thread-003",
                        subject: "Vendor Invoice #INV-2024-0892",
                        senderEmail: "billing@supplierco.net", senderName: "SupplierCo Billing",
                        recipientEmails: ["user@xqmsg.com"], ccEmails: ["ap@acmecorp.com"],
                        bodyPreview: "Please find attached invoice INV-2024-0892 for $42,500. Payment is due within 30 days.",
                        encryptedPayloadId: "enc-003", sensitivity: .internal_,
                        receivedAt: now.addingTimeInterval(-14400), isRead: true, hasAttachments: true),
            SecureEmail(id: UUID(), messageId: "msg-004", threadId: "thread-004",
                        subject: "Team Lunch This Friday?",
                        senderEmail: "alex.rodriguez@acmecorp.com", senderName: "Alex Rodriguez",
                        recipientEmails: ["user@xqmsg.com"], ccEmails: ["team@acmecorp.com"],
                        bodyPreview: "Hey, are you free for team lunch this Friday around noon? There's a new Thai place everyone wants to try.",
                        encryptedPayloadId: "enc-004", sensitivity: .public_,
                        receivedAt: now.addingTimeInterval(-21600), isRead: false, hasAttachments: false),
            SecureEmail(id: UUID(), messageId: "msg-005", threadId: "thread-005",
                        subject: "VERIFY YOUR ACCOUNT NOW — Security Alert",
                        senderEmail: "security@micros0ft-alerts.com", senderName: "Microsoft Security Team",
                        recipientEmails: ["user@xqmsg.com"], ccEmails: [],
                        bodyPreview: "Unusual sign-in activity detected. Verify your account immediately to avoid suspension. Click here to confirm.",
                        encryptedPayloadId: "enc-005", sensitivity: .internal_,
                        receivedAt: now.addingTimeInterval(-28800), isRead: false, hasAttachments: false),
        ]
    }
}
