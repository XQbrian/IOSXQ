import Foundation
import XQCore
import XQEmailIntelligence
import XQPolicy

@MainActor
final class EmailDetailViewModel: ObservableObject {

    // MARK: - Published State

    @Published var risk: EmailRiskAssessment? = nil
    @Published var actions: [ExtractedEmailAction] = []
    @Published var fullBody: String? = nil
    @Published var isAnalyzing: Bool = false
    @Published var isLoadingBody: Bool = false
    @Published var suggestedReply: String? = nil
    @Published var isSuggestingReply: Bool = false
    @Published var error: String? = nil

    let email: SecureEmail

    private let orchestrator: any EmailOrchestrator
    private let riskDetector: LocalEmailIntelligenceProvider
    private let policy: PolicyBundle

    init(email: SecureEmail, orchestrator: any EmailOrchestrator) {
        self.email = email
        self.orchestrator = orchestrator
        self.riskDetector = LocalEmailIntelligenceProvider()
        self.policy = Self.defaultPolicy()
    }

    // MARK: - Analyze

    func analyze() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        error = nil
        do {
            let assessment = try await riskDetector.assess(
                email: email,
                senderProfile: nil,
                policy: policy
            )
            risk = assessment

            let extracted = try await riskDetector.extractActions(from: email, policy: policy)
            actions = extracted
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Load full body

    func loadBody(graphClient: MicrosoftGraphClient?) async {
        guard fullBody == nil else { return }
        isLoadingBody = true
        defer { isLoadingBody = false }
        if let client = graphClient,
           let body = try? await client.getMessageBody(id: email.messageId) {
            let raw = body.content ?? ""
            fullBody = raw.isEmpty ? email.bodyPreview : stripHTML(raw)
        } else {
            fullBody = email.bodyPreview
        }
    }

    // MARK: - Suggest reply

    func suggestReply() async {
        isSuggestingReply = true
        defer { isSuggestingReply = false }
        do {
            let draft = try await orchestrator.suggestReply(
                for: email,
                userContext: "",
                policy: policy
            )
            suggestedReply = draft
        } catch {
            suggestedReply = nil
            self.error = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func stripHTML(_ html: String) -> String {
        guard let data = html.data(using: .utf8) else { return html }
        if let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            return attributed.string
        }
        var result = html
        while let open = result.range(of: "<"),
              let close = result.range(of: ">", range: open.upperBound..<result.endIndex) {
            result.removeSubrange(open.lowerBound...close.upperBound)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func defaultPolicy() -> PolicyBundle {
        PolicyBundle(
            version: "1.0",
            signatureHex: String(repeating: "a", count: 64),
            rules: SensitivityLevel.allCases.map { level in
                PolicyRule(id: UUID(), name: "\(level.rawValue) Policy", sensitivity: level,
                           allowExternalShare: level == .public_ || level == .internal_,
                           maxShareExpiryDays: level == .restricted ? nil : 30,
                           requireApprovalFromRole: level == .restricted ? "admin" : nil,
                           cloudAIPermitted: level == .public_)
            },
            fetchedAt: Date()
        )
    }
}
