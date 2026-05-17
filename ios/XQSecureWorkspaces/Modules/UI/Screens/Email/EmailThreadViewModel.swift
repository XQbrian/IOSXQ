import Foundation
import XQCore
import XQEmailIntelligence
import XQPolicy

@MainActor
final class EmailThreadViewModel: ObservableObject {

    // MARK: - Published State

    @Published var thread: EmailThread? = nil
    @Published var summary: ThreadSummary? = nil
    @Published var actions: [ExtractedEmailAction] = []
    @Published var riskAssessment: EmailRiskAssessment? = nil
    @Published var senderProfile: SenderProfile? = nil
    @Published var isAnalyzing: Bool = false
    @Published var isSummaryExpanded: Bool = true
    @Published var error: String? = nil

    // MARK: - Dependencies

    private let orchestrator: any EmailOrchestrator
    private let profileStore: any SenderProfileStore

    init(orchestrator: any EmailOrchestrator, profileStore: any SenderProfileStore) {
        self.orchestrator = orchestrator
        self.profileStore = profileStore
    }

    // MARK: - Public API

    func loadThread(threadId: String, session: XQSession) async {
        error = nil
        // In production this would fetch from the XQ-encrypted email store via the thread ID.
        thread = makeSampleThread(id: threadId)
        if let firstSender = thread?.messages.first?.senderEmail {
            senderProfile = await profileStore.profile(for: firstSender, tenantId: session.tenantId)
        }
    }

    func analyzeWithAI(policy: PolicyBundle) async {
        guard let thread else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        error = nil

        let session = XQSession(
            userId: "local-user",
            tenantId: "stub-tenant",
            accessToken: "",      // never persisted to disk
            expiresAt: Date(timeIntervalSinceNow: 3600),
            apiVersion: .v3
        )

        do {
            // Analyze each message, collect all results.
            var allActions: [ExtractedEmailAction] = []
            var latestRisk: EmailRiskAssessment? = nil
            var latestProfile: SenderProfile? = nil

            for message in thread.messages {
                let result = try await orchestrator.analyze(
                    email: message,
                    session: session,
                    policy: policy
                )
                allActions.append(contentsOf: result.triage.extractedActionCount > 0
                    ? (0..<result.triage.extractedActionCount).map { idx in
                        ExtractedEmailAction(
                            text: "Action item \(idx + 1) from \(message.senderName)",
                            assignee: nil,
                            deadline: result.triage.deadlineAt,
                            type: .commitment,
                            confidence: 0.75,
                            sourceMessageId: message.messageId
                        )
                      }
                    : []
                )
                if latestRisk == nil || result.riskAssessment.riskScore > (latestRisk?.riskScore ?? 0) {
                    latestRisk = result.riskAssessment
                }
                if latestProfile == nil {
                    latestProfile = result.senderProfile
                }
            }

            // Build a thread-level summary from the highest-risk message's assessment.
            let allBodies = thread.messages.map(\.bodyPreview).joined(separator: " ")
            let wordCount = allBodies.split(separator: " ").count
            let threadSentiment: ThreadSentiment = {
                let low = allBodies.lowercased()
                if low.contains("escalat") { return .escalating }
                if low.contains("urgent") { return .urgent }
                if low.contains("concern") { return .tense }
                if low.contains("great") || low.contains("thank") { return .positive }
                return .neutral
            }()

            let containsPHI = thread.messages.contains { $0.sensitivity == .restricted }

            summary = ThreadSummary(
                threadId: thread.id,
                oneSentenceSummary: "Thread \"\(thread.subject)\" contains \(thread.messageCount) message(s)" +
                    (containsPHI ? " with PHI content — analyzed on-device only." : "."),
                keyDecisions: ["No explicit decisions recorded."],
                actionItems: allActions,
                unresolvedIssues: [],
                blockers: [],
                sentiment: threadSentiment,
                messageCount: thread.messageCount,
                compressedFromWordCount: wordCount,
                compressedToWordCount: max(30, wordCount / 6),
                wasCloudProcessed: false
            )

            actions = allActions
            riskAssessment = latestRisk
            if let profile = latestProfile { senderProfile = profile }

        } catch {
            self.error = error.localizedDescription
        }
    }

    func markActionComplete(_ actionId: UUID) {
        actions.removeAll { $0.id == actionId }
        if var currentSummary = summary {
            let updatedItems = currentSummary.actionItems.filter { $0.id != actionId }
            currentSummary = ThreadSummary(
                threadId: currentSummary.threadId,
                oneSentenceSummary: currentSummary.oneSentenceSummary,
                keyDecisions: currentSummary.keyDecisions,
                actionItems: updatedItems,
                unresolvedIssues: currentSummary.unresolvedIssues,
                blockers: currentSummary.blockers,
                sentiment: currentSummary.sentiment,
                messageCount: currentSummary.messageCount,
                compressedFromWordCount: currentSummary.compressedFromWordCount,
                compressedToWordCount: currentSummary.compressedToWordCount,
                wasCloudProcessed: currentSummary.wasCloudProcessed
            )
            summary = currentSummary
        }
    }

    // MARK: - Private Helpers

    private func makeSampleThread(id: String) -> EmailThread {
        let now = Date()
        let message1 = SecureEmail(
            id: UUID(),
            messageId: "\(id)-msg-1",
            threadId: id,
            subject: "Project Phoenix — Status Update",
            senderEmail: "pm@acmecorp.com",
            senderName: "Jordan Lee",
            recipientEmails: ["user@xqmsg.com"],
            ccEmails: ["team@acmecorp.com"],
            bodyPreview: "Hi team, please review the attached project status update. We're blocked on vendor approval and need sign-off by end of week.",
            encryptedPayloadId: "enc-thread-\(id)-1",
            sensitivity: .confidential,
            receivedAt: now.addingTimeInterval(-86400),
            isRead: true,
            hasAttachments: true
        )
        let message2 = SecureEmail(
            id: UUID(),
            messageId: "\(id)-msg-2",
            threadId: id,
            subject: "RE: Project Phoenix — Status Update",
            senderEmail: "legal@acmecorp.com",
            senderName: "Sam Carter",
            recipientEmails: ["pm@acmecorp.com", "user@xqmsg.com"],
            ccEmails: [],
            bodyPreview: "I'll follow up with the vendor today. Legal review of the amended contract is still in progress — hoping to have it ready by Monday.",
            encryptedPayloadId: "enc-thread-\(id)-2",
            sensitivity: .confidential,
            receivedAt: now.addingTimeInterval(-43200),
            isRead: false,
            hasAttachments: false
        )
        return EmailThread(
            id: id,
            subject: "Project Phoenix — Status Update",
            participants: ["pm@acmecorp.com", "legal@acmecorp.com", "user@xqmsg.com"],
            messageCount: 2,
            latestAt: message2.receivedAt,
            sensitivity: .confidential,
            messages: [message1, message2],
            summary: nil
        )
    }
}
