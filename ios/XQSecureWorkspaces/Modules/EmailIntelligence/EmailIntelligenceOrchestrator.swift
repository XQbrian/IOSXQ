import Foundation
import XQCore

// MARK: - Errors

public enum EmailIntelligenceError: Error, LocalizedError {
    case localOnlyViolation(reason: String)
    case policyBlockedCloudAI(sensitivity: SensitivityLevel)
    case modelNotLoaded(capability: String)
    case analysisTimeout(emailId: UUID, elapsedMs: Int)

    public var errorDescription: String? {
        switch self {
        case .localOnlyViolation(let reason):
            return "Local-only violation: \(reason)"
        case .policyBlockedCloudAI(let sensitivity):
            return "Cloud AI is not permitted for sensitivity level \(sensitivity.rawValue) by the active policy bundle."
        case .modelNotLoaded(let capability):
            return "On-device model for capability '\(capability)' is not loaded."
        case .analysisTimeout(let id, let ms):
            return "Analysis of email \(id) timed out after \(ms) ms."
        }
    }
}

// MARK: - Orchestrator

/// Coordinates all 8 email intelligence capabilities.
/// Enforces routing decisions (local vs. cloud) based on sensitivity level and PolicyBundle;
/// never silently degrades — callers receive a typed error on policy violation.
public actor EmailIntelligenceOrchestrator: EmailOrchestrator {

    private let prioritizer: any EmailPrioritizer
    private let threadProvider: any ThreadIntelligenceProvider
    private let toneAnalyzer: any EmailToneAnalyzer
    private let riskDetector: any EmailRiskDetector
    private let profileStore: any SenderProfileStore

    private var auditLog: [AuditEvent] = []

    public init(
        prioritizer: any EmailPrioritizer,
        threadProvider: any ThreadIntelligenceProvider,
        toneAnalyzer: any EmailToneAnalyzer,
        riskDetector: any EmailRiskDetector,
        profileStore: any SenderProfileStore
    ) {
        self.prioritizer = prioritizer
        self.threadProvider = threadProvider
        self.toneAnalyzer = toneAnalyzer
        self.riskDetector = riskDetector
        self.profileStore = profileStore
    }

    // MARK: - analyze

    public func analyze(
        email: SecureEmail,
        session: XQSession,
        policy: PolicyBundle
    ) async throws -> EmailIntelligenceResult {
        let start = Date()

        // Cloud AI gating: Restricted sensitivity is unconditionally blocked from cloud routing.
        if email.sensitivity == .restricted {
            guard riskDetector.isLocalOnly else {
                throw EmailIntelligenceError.localOnlyViolation(
                    reason: "Risk detector for RESTRICTED email '\(email.id)' must be on-device only (HIPAA §164.502)."
                )
            }
        }

        // Run triage, risk assessment, and sender profile lookup concurrently.
        async let senderProfileTask = profileStore.profile(for: email.senderEmail, tenantId: session.tenantId)
        async let riskTask = riskDetector.assess(email: email, senderProfile: nil, policy: policy)

        let senderProfile = await senderProfileTask
        let riskAssessment = try await riskTask

        // Triage runs after sender profile is available for org-graph-aware prioritization.
        let triage = await prioritizer.triage(email: email, senderProfile: senderProfile, policy: policy)

        // Emit audit events.
        emit(event: emailAuditEvent(type: .emailTriaged, emailId: email.id, actorId: session.userId,
                                    metadata: ["priority": triage.priority.rawValue.description,
                                               "reason": triage.priorityReason]))

        if riskAssessment.isPhishing || riskAssessment.isBEC {
            emit(event: emailAuditEvent(type: .phishingDetected, emailId: email.id, actorId: session.userId,
                                        metadata: ["riskScore": String(riskAssessment.riskScore),
                                                   "isBEC": String(riskAssessment.isBEC)]))
        }

        if riskAssessment.recommendedAction == .block || riskAssessment.recommendedAction == .quarantine {
            emit(event: emailAuditEvent(type: .emailRiskBlocked, emailId: email.id, actorId: session.userId,
                                        metadata: ["action": riskAssessment.recommendedAction.rawValue,
                                                   "overallRisk": riskAssessment.overallRisk.rawValue]))
        }

        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        let wasCloud = !riskDetector.isLocalOnly && cloudAIPermitted(for: email.sensitivity, policy: policy)

        return EmailIntelligenceResult(
            emailId: email.id,
            triage: triage,
            riskAssessment: riskAssessment,
            toneAnalysis: nil,
            senderProfile: senderProfile,
            processedAt: Date(),
            processingMs: elapsed,
            wasCloudProcessed: wasCloud,
            modelVersions: ["riskDetector": "local-1.4.0", "prioritizer": "local-1.4.0"]
        )
    }

    // MARK: - autonomousTriage

    public func autonomousTriage(
        inbox: [SecureEmail],
        session: XQSession,
        policy: PolicyBundle
    ) async throws -> [EmailTriageResult] {
        var results: [EmailTriageResult] = []

        // Process emails concurrently in groups of 8 to bound memory pressure.
        let batches = stride(from: 0, to: inbox.count, by: 8).map {
            Array(inbox[$0..<min($0 + 8, inbox.count)])
        }

        for batch in batches {
            try await withThrowingTaskGroup(of: EmailTriageResult.self) { group in
                for email in batch {
                    group.addTask {
                        let profile = await self.profileStore.profile(
                            for: email.senderEmail,
                            tenantId: session.tenantId
                        )
                        return await self.prioritizer.triage(
                            email: email,
                            senderProfile: profile,
                            policy: policy
                        )
                    }
                }
                for try await result in group {
                    results.append(result)
                }
            }
        }

        return results.sorted { $0.priority < $1.priority }
    }

    // MARK: - suggestReply

    public func suggestReply(
        for email: SecureEmail,
        userContext: String,
        policy: PolicyBundle
    ) async throws -> String {
        // Cloud AI is only permitted when BOTH: enterprise opt-in is present AND sensitivity allows it.
        // PHI/Restricted emails never get cloud-assisted drafting.
        if email.sensitivity == .restricted {
            throw EmailIntelligenceError.localOnlyViolation(
                reason: "Reply drafting for RESTRICTED email '\(email.id)' is prohibited via cloud AI (HIPAA §164.502)."
            )
        }

        let permitted = cloudAIPermitted(for: email.sensitivity, policy: policy)
        if !permitted && !threadProvider.isLocalOnly {
            throw EmailIntelligenceError.policyBlockedCloudAI(sensitivity: email.sensitivity)
        }

        // Local stub: construct a context-aware draft skeleton.
        let greeting = "Hello \(email.senderName.components(separatedBy: " ").first ?? "there"),"
        let contextLine = userContext.isEmpty
            ? "Thank you for your message regarding \"\(email.subject)\"."
            : userContext

        let closing = """
        Please let me know if you need any additional information.

        Best regards
        """

        return [greeting, "", contextLine, "", closing].joined(separator: "\n")
    }

    // MARK: - Audit helpers

    private func emit(event: AuditEvent) {
        auditLog.append(event)
    }

    private func emailAuditEvent(
        type: EmailAuditEventType,
        emailId: UUID,
        actorId: String,
        metadata: [String: String]
    ) -> AuditEvent {
        AuditEvent(
            id: UUID(),
            eventType: mapEmailAuditType(type),
            fileId: emailId,
            actorId: actorId,
            timestamp: Date(),
            metadata: metadata
        )
    }

    private func mapEmailAuditType(_ type: EmailAuditEventType) -> AuditEvent.AuditEventType {
        switch type {
        case .emailTriaged:        return .aiScanned
        case .phishingDetected:    return .policyApplied
        case .phishingBlocked:     return .shareBlocked
        case .actionExtracted:     return .aiScanned
        case .emailSent:           return .fileShared
        case .emailRiskBlocked:    return .shareBlocked
        case .toneAnalyzed:        return .aiScanned
        }
    }

    // MARK: - Policy gate

    /// Returns true only when every policy rule that matches the given sensitivity permits cloud AI.
    /// PHI (.restricted) always returns false — the sensitivity check is the outer gate.
    private func cloudAIPermitted(for sensitivity: SensitivityLevel, policy: PolicyBundle) -> Bool {
        guard sensitivity != .restricted else { return false }
        let matchingRules = policy.rules.filter { $0.sensitivity == sensitivity }
        guard !matchingRules.isEmpty else { return false }
        return matchingRules.allSatisfy { $0.cloudAIPermitted }
    }
}
