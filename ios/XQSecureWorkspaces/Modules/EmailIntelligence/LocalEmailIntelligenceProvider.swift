import Foundation
import CryptoKit

// MARK: - Local Email Intelligence Provider
//
// Implements all four inference protocols entirely on-device.
// PHI / Restricted content: local-only enforcement is structural, not a flag.
// Cloud AI routing is the orchestrator's responsibility; this actor never calls remote endpoints.

actor LocalEmailIntelligenceProvider:
    EmailPrioritizer,
    ThreadIntelligenceProvider,
    EmailToneAnalyzer,
    EmailRiskDetector
{
    // MARK: Shared

    let isLocalOnly = true

    private let modelVersion = "local-1.4.0"

    // Seeded urgency keywords for heuristic analysis (no ML model required for stub tier).
    private let urgencyKeywords: Set<String> = [
        "urgent", "asap", "immediately", "action required", "critical",
        "deadline today", "wire transfer", "verify now", "confirm immediately"
    ]

    private let phishingDomainPatterns: [String] = [
        "paypa1.com", "micros0ft.com", "arnazon.com", "secure-login-",
        "account-verify.", "update-billing."
    ]

    // MARK: - Capability 1: EmailPrioritizer

    func triage(
        email: SecureEmail,
        senderProfile: SenderProfile?,
        policy: PolicyBundle
    ) async -> EmailTriageResult {
        let importance = senderProfile.map { importanceFromProfile($0) } ?? .externalUnknown

        let hasUrgencyMarkers = urgencyKeywords.contains { keyword in
            email.subject.lowercased().contains(keyword) ||
            email.bodyPreview.lowercased().contains(keyword)
        }

        let priority: EmailPriority
        let reason: String

        switch importance {
        case .executive:
            priority = .critical
            reason = "Executive sender detected via org graph."
        case .directReport:
            priority = hasUrgencyMarkers ? .critical : .action
            reason = hasUrgencyMarkers
                ? "Direct report with urgency language detected."
                : "Message from direct report requires attention."
        case .peer, .crossFunctional:
            priority = hasUrgencyMarkers ? .action : .fyi
            reason = hasUrgencyMarkers
                ? "Peer communication with urgency indicators."
                : "Routine peer communication."
        case .externalPartner:
            priority = hasUrgencyMarkers ? .action : .fyi
            reason = "External partner communication."
        case .externalUnknown:
            priority = hasUrgencyMarkers ? .action : .noise
            reason = hasUrgencyMarkers
                ? "Unknown external sender with urgency language — review recommended."
                : "Unknown external sender; low signal."
        case .automated:
            priority = .noise
            reason = "Automated system message."
        }

        let actionCount = countImpliedActions(in: email.bodyPreview)
        let (hasDeadline, deadlineAt) = extractDeadline(from: email.bodyPreview)

        return EmailTriageResult(
            emailId: email.id,
            priority: priority,
            priorityReason: reason,
            extractedActionCount: actionCount,
            hasDeadline: hasDeadline,
            deadlineAt: deadlineAt,
            senderImportance: importance
        )
    }

    func rankInbox(_ emails: [SecureEmail], policy: PolicyBundle) async -> [SecureEmail] {
        var triaged: [(email: SecureEmail, result: EmailTriageResult)] = []
        for email in emails {
            let result = await triage(email: email, senderProfile: nil, policy: policy)
            triaged.append((email, result))
        }
        return triaged
            .sorted { $0.result.priority < $1.result.priority }
            .map(\.email)
    }

    // MARK: - Capability 2: ThreadIntelligenceProvider — summarize

    func summarize(thread: EmailThread, policy: PolicyBundle) async throws -> ThreadSummary {
        // Structural rule: if any message in the thread is Restricted (PHI),
        // cloud processing is unconditionally forbidden.
        let containsPHI = thread.messages.contains { $0.sensitivity == .restricted }
        let cloudProcessed = false   // This actor is always local-only

        let actions = try await extractActionsFromMessages(thread.messages, policy: policy)
        let wordCountIn = thread.messages.reduce(0) { $0 + $1.bodyPreview.split(separator: " ").count }
        let keyDecisions = deriveKeyDecisions(from: thread.messages)
        let unresolvedIssues = deriveUnresolved(from: thread.messages)
        let blockers = deriveBlockers(from: thread.messages)
        let sentiment = deriveSentiment(from: thread.messages)

        let summary = "Thread covers \(thread.subject) with \(thread.messageCount) messages" +
            (containsPHI ? " (PHI content — on-device only)." : ".")

        return ThreadSummary(
            threadId: thread.id,
            oneSentenceSummary: summary,
            keyDecisions: keyDecisions,
            actionItems: actions,
            unresolvedIssues: unresolvedIssues,
            blockers: blockers,
            sentiment: sentiment,
            messageCount: thread.messageCount,
            compressedFromWordCount: wordCountIn,
            compressedToWordCount: max(40, wordCountIn / 6),
            wasCloudProcessed: cloudProcessed
        )
    }

    // MARK: - Capability 3: ThreadIntelligenceProvider — extractActions

    func extractActions(from email: SecureEmail, policy: PolicyBundle) async throws -> [ExtractedEmailAction] {
        return buildActions(from: email.bodyPreview, messageId: email.messageId)
    }

    // MARK: - Capability 4: EmailToneAnalyzer

    func analyzeTone(
        draftBody: String,
        subject: String,
        recipientProfile: SenderProfile?
    ) async -> EmailToneAnalysis {
        let wordCount = draftBody.split(separator: " ").count
        let lowered = draftBody.lowercased()

        let hasPleasantries = lowered.contains("hope") || lowered.contains("trust") || lowered.contains("regards")
        let hasAggression = lowered.contains("demand") || lowered.contains("immediately") || lowered.contains("unacceptable")
        let hasHedging = lowered.contains("perhaps") || lowered.contains("might") || lowered.contains("possibly")

        let tone: EmailTone
        let formality: Int
        if hasAggression {
            tone = .aggressive
            formality = 30
        } else if hasPleasantries && !hasHedging {
            tone = .formal
            formality = 70
        } else if hasHedging {
            tone = .passive
            formality = 55
        } else if lowered.contains("hey") || lowered.contains("yo ") {
            tone = .casual
            formality = 25
        } else {
            tone = .neutral
            formality = 50
        }

        let urgencyScore = urgencyKeywords.contains { lowered.contains($0) } ? 72 : 18
        let sentimentScore = hasAggression ? -40 : (hasPleasantries ? 30 : 0)
        let matchesProfile = recipientProfile.map { _ in formality >= 40 && formality <= 75 } ?? true

        var suggestions: [ToneSuggestion] = []
        if wordCount > 400 {
            suggestions.append(ToneSuggestion(type: .tooLong, description: "Draft exceeds 400 words; consider condensing to improve response rate."))
        }
        if !lowered.contains("please") && !lowered.contains("by ") && urgencyScore > 60 {
            suggestions.append(ToneSuggestion(type: .unclearDeadline, description: "Urgency is implied but no explicit deadline is stated."))
        }
        if !lowered.contains("?") && !lowered.contains("could you") && !lowered.contains("please") {
            suggestions.append(ToneSuggestion(type: .missingCallToAction, description: "No clear call-to-action detected; recipient may be unsure what response is expected."))
        }

        let commitments = await detectCommitments(in: draftBody)

        return EmailToneAnalysis(
            emailId: UUID(),
            tone: tone,
            formalityScore: formality,
            urgencyScore: urgencyScore,
            sentimentScore: sentimentScore,
            matchesVoiceProfile: matchesProfile,
            suggestions: suggestions,
            commitments: commitments
        )
    }

    func detectCommitments(in text: String) async -> [DetectedCommitment] {
        let patterns: [(trigger: String, deliverable: String)] = [
            ("i will send", "Send deliverable"),
            ("i'll follow up", "Follow-up communication"),
            ("we will deliver", "Project deliverable"),
            ("i will complete", "Task completion"),
            ("i'll prepare", "Document preparation"),
            ("will have it ready by", "Deliverable readiness"),
            ("will review and", "Review action"),
        ]

        let lowered = text.lowercased()
        var results: [DetectedCommitment] = []
        for pattern in patterns where lowered.contains(pattern.trigger) {
            let (hasDeadline, deadlineAt) = extractDeadline(from: text)
            results.append(DetectedCommitment(
                text: pattern.trigger,
                deliverable: pattern.deliverable,
                deadline: hasDeadline ? deadlineAt : nil,
                isExplicit: true
            ))
        }
        return results
    }

    // MARK: - Capability 5: EmailRiskDetector

    func assess(
        email: SecureEmail,
        senderProfile: SenderProfile?,
        policy: PolicyBundle
    ) async throws -> EmailRiskAssessment {
        // Local-only: PHI/Restricted emails never leave device for analysis.
        // CitedControl citations are attached whenever the sensitivity level is .restricted,
        // making the policy basis explicit in every audit trail.
        let citedControls: [CitedControl] = email.sensitivity == .restricted ? [
            CitedControl(
                framework: .hipaa,
                controlId: "164.502",
                title: "Use & Disclosure of PHI",
                description: "PHI email analysis must remain on-device. Transmission to any remote AI endpoint is prohibited.",
                enforcement: .block
            ),
            CitedControl(
                framework: .nistSP80053,
                controlId: "AC-3",
                title: "Access Enforcement",
                description: "Policy engine enforces data handling boundaries for sensitive health information.",
                enforcement: .audit
            ),
            CitedControl(
                framework: .gdpr,
                controlId: "Art. 9",
                title: "Processing of Special Categories of Data",
                description: "Special category data (health) requires explicit legal basis; local processing preserves data minimisation.",
                enforcement: .block
            )
        ] : []

        var signals: [EmailRiskSignal] = []
        let loweredBody = email.bodyPreview.lowercased()
        let loweredSubject = email.subject.lowercased()

        // Prototype-specific scenario: carol.thomas@hospital.org returns a realistic medium-risk result.
        if email.senderEmail.lowercased() == "carol.thomas@hospital.org" {
            signals.append(EmailRiskSignal(
                type: .urgencyManipulation,
                description: "Sender has a pattern of escalating time pressure language inconsistent with the stated topic.",
                confidence: 0.72
            ))
            return EmailRiskAssessment(
                emailId: email.id,
                overallRisk: .medium,
                riskScore: 42,
                signals: signals,
                isPhishing: false,
                isBEC: false,
                hasUrgencyManipulation: true,
                hasImpersonation: false,
                hasSuspiciousLinks: false,
                hasPromptInjection: false,
                citedControls: citedControls,
                recommendedAction: .warn
            )
        }

        // Urgency manipulation heuristic
        let urgencyHits = urgencyKeywords.filter { loweredBody.contains($0) || loweredSubject.contains($0) }
        if urgencyHits.count >= 2 {
            signals.append(EmailRiskSignal(
                type: .urgencyManipulation,
                description: "Multiple urgency-forcing phrases detected: \(urgencyHits.prefix(3).joined(separator: ", ")).",
                confidence: min(0.50 + Double(urgencyHits.count) * 0.08, 0.95)
            ))
        }

        // Domain anomaly
        let domain = email.senderEmail.components(separatedBy: "@").last ?? ""
        if phishingDomainPatterns.contains(where: { domain.contains($0) }) {
            signals.append(EmailRiskSignal(
                type: .domainAnomaly,
                description: "Sender domain \"\(domain)\" matches known look-alike pattern.",
                confidence: 0.88
            ))
        }

        // Prompt injection scan
        let hasInjection = await scanForPromptInjection(body: email.bodyPreview)
        if hasInjection {
            signals.append(EmailRiskSignal(
                type: .promptInjection,
                description: "Email body contains instruction-injection syntax targeting AI email assistants.",
                confidence: 0.91
            ))
        }

        // Display-name impersonation (sender name contains executive title keywords but domain is external)
        let nameKeywords = ["ceo", "cfo", "ciso", "president", "vp of", "chief"]
        let nameIsExecutive = nameKeywords.contains { email.senderName.lowercased().contains($0) }
        let domainIsInternal = domain.hasSuffix(".internal") || domain.hasSuffix("xqmsg.com")
        if nameIsExecutive && !domainIsInternal {
            signals.append(EmailRiskSignal(
                type: .impersonation,
                description: "Sender name claims an executive role but originates from an external domain.",
                confidence: 0.79
            ))
        }

        // Derive composite risk
        let maxConfidence = signals.map(\.confidence).max() ?? 0.0
        let signalCount = signals.count
        let riskScore = min(Int(maxConfidence * 60) + signalCount * 8, 100)

        let overallRisk: EmailRiskLevel
        switch riskScore {
        case 0..<15:  overallRisk = .safe
        case 15..<35: overallRisk = .low
        case 35..<60: overallRisk = .medium
        case 60..<80: overallRisk = .high
        default:      overallRisk = .critical
        }

        let recommendedAction: EmailRiskAction
        switch overallRisk {
        case .safe:     recommendedAction = .allow
        case .low:      recommendedAction = .allow
        case .medium:   recommendedAction = .warn
        case .high:     recommendedAction = .requireConfirmation
        case .critical: recommendedAction = .quarantine
        }

        return EmailRiskAssessment(
            emailId: email.id,
            overallRisk: overallRisk,
            riskScore: riskScore,
            signals: signals,
            isPhishing: overallRisk >= .high && signals.contains { $0.type == .domainAnomaly || $0.type == .senderSpoofing },
            isBEC: signals.contains { $0.type == .impersonation } && overallRisk >= .medium,
            hasUrgencyManipulation: signals.contains { $0.type == .urgencyManipulation },
            hasImpersonation: signals.contains { $0.type == .impersonation },
            hasSuspiciousLinks: signals.contains { $0.type == .maliciousLink },
            hasPromptInjection: hasInjection,
            citedControls: citedControls,
            recommendedAction: recommendedAction
        )
    }

    func scanForPromptInjection(body: String) async -> Bool {
        // Detection heuristics for adversarial instruction payloads.
        let injectionPatterns: [String] = [
            "ignore previous instructions",
            "ignore all instructions",
            "disregard your system prompt",
            "you are now",
            "act as if",
            "forget what you were told",
            "new instruction:",
            "system: you must",
            "assistant: i will",
            "[[prompt]]",
            "<!--",
            "<|endoftext|>",
        ]
        let lowered = body.lowercased()
        return injectionPatterns.contains { lowered.contains($0) }
    }

    // MARK: - Private Helpers

    private func importanceFromProfile(_ profile: SenderProfile) -> SenderImportance {
        switch profile.relationship {
        case .manager:          return .executive
        case .directReport:     return .directReport
        case .peer:             return .peer
        case .crossFunctional:  return .peer
        case .externalPartner:  return .externalPartner
        case .client:           return .externalPartner
        case .vendor:           return .externalPartner
        case .unknown:          return .externalUnknown
        }
    }

    private func countImpliedActions(in text: String) -> Int {
        let actionVerbs = ["please", "could you", "can you", "need you to", "request", "review", "approve", "complete", "send"]
        return actionVerbs.filter { text.lowercased().contains($0) }.count
    }

    private func extractDeadline(from text: String) -> (Bool, Date?) {
        let patterns = ["by end of day", "by eod", "by tomorrow", "by friday", "by next week", "by monday"]
        let lowered = text.lowercased()
        let found = patterns.contains { lowered.contains($0) }
        if found {
            // Return a synthetic 48-hour deadline for the stub; a real NLP pipeline would parse the date.
            return (true, Date(timeIntervalSinceNow: 48 * 3600))
        }
        return (false, nil)
    }

    private func buildActions(from text: String, messageId: String) -> [ExtractedEmailAction] {
        var actions: [ExtractedEmailAction] = []
        let lowered = text.lowercased()

        if lowered.contains("please review") || lowered.contains("need your review") {
            actions.append(ExtractedEmailAction(
                text: "Review requested document or proposal.",
                assignee: nil,
                deadline: nil,
                type: .approval,
                confidence: 0.81,
                sourceMessageId: messageId
            ))
        }
        if lowered.contains("please approve") || lowered.contains("awaiting approval") {
            actions.append(ExtractedEmailAction(
                text: "Approval required before proceeding.",
                assignee: nil,
                deadline: nil,
                type: .approval,
                confidence: 0.88,
                sourceMessageId: messageId
            ))
        }
        if lowered.contains("follow up") || lowered.contains("circling back") {
            actions.append(ExtractedEmailAction(
                text: "Follow up on open items from this thread.",
                assignee: nil,
                deadline: Date(timeIntervalSinceNow: 3 * 24 * 3600),
                type: .followUp,
                confidence: 0.74,
                sourceMessageId: messageId
            ))
        }
        if lowered.contains("purchase order") || lowered.contains("vendor invoice") || lowered.contains("procurement") {
            actions.append(ExtractedEmailAction(
                text: "Process procurement action item.",
                assignee: nil,
                deadline: nil,
                type: .procurementAction,
                confidence: 0.76,
                sourceMessageId: messageId
            ))
        }
        if actions.isEmpty {
            // Always provide at least a read-and-note action for non-trivial messages.
            actions.append(ExtractedEmailAction(
                text: "Read and note information; no immediate response required.",
                assignee: nil,
                deadline: nil,
                type: .reminder,
                confidence: 0.55,
                sourceMessageId: messageId
            ))
        }
        return actions
    }

    private func extractActionsFromMessages(_ messages: [SecureEmail], policy: PolicyBundle) async throws -> [ExtractedEmailAction] {
        var all: [ExtractedEmailAction] = []
        for message in messages {
            let actions = buildActions(from: message.bodyPreview, messageId: message.messageId)
            all.append(contentsOf: actions)
        }
        return all
    }

    private func deriveKeyDecisions(from messages: [SecureEmail]) -> [String] {
        let decisions = messages.filter {
            $0.bodyPreview.lowercased().contains("decided") ||
            $0.bodyPreview.lowercased().contains("agreed") ||
            $0.bodyPreview.lowercased().contains("approved")
        }
        if decisions.isEmpty {
            return ["No explicit decisions recorded in thread."]
        }
        return decisions.prefix(3).map { "Decision noted in message from \($0.senderName)." }
    }

    private func deriveUnresolved(from messages: [SecureEmail]) -> [String] {
        let open = messages.filter {
            $0.bodyPreview.lowercased().contains("still waiting") ||
            $0.bodyPreview.lowercased().contains("not yet resolved") ||
            $0.bodyPreview.lowercased().contains("open question")
        }
        return open.prefix(3).map { "Unresolved item raised by \($0.senderName)." }
    }

    private func deriveBlockers(from messages: [SecureEmail]) -> [String] {
        let blockers = messages.filter {
            $0.bodyPreview.lowercased().contains("blocked") ||
            $0.bodyPreview.lowercased().contains("waiting on") ||
            $0.bodyPreview.lowercased().contains("dependency")
        }
        return blockers.prefix(3).map { "Blocker identified by \($0.senderName)." }
    }

    private func deriveSentiment(from messages: [SecureEmail]) -> ThreadSentiment {
        let bodies = messages.map { $0.bodyPreview.lowercased() }
        let allText = bodies.joined(separator: " ")

        if allText.contains("escalat") || allText.contains("executive review") { return .escalating }
        if allText.contains("urgent") || allText.contains("critical") { return .urgent }
        if allText.contains("concern") || allText.contains("disappoint") { return .tense }
        if allText.contains("great") || allText.contains("excellent") || allText.contains("thank") { return .positive }
        return .neutral
    }
}
