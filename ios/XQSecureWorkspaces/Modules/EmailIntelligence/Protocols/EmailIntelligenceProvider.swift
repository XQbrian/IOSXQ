import Foundation
import XQCore

// MARK: - Capability 1: Intelligent Prioritization

public protocol EmailPrioritizer: Sendable {
    /// Assign a priority and triage metadata to a single email.
    func triage(email: SecureEmail, senderProfile: SenderProfile?, policy: PolicyBundle) async -> EmailTriageResult
    /// Return the inbox sorted by descending priority (critical first).
    func rankInbox(_ emails: [SecureEmail], policy: PolicyBundle) async -> [SecureEmail]
}

// MARK: - Capabilities 2 & 3: Thread Summarization + Action Extraction

public protocol ThreadIntelligenceProvider: Sendable {
    /// Always false for local implementations; true only when enterprise policy permits cloud AI.
    var isLocalOnly: Bool { get }
    /// Compress a full thread into key decisions, action items, blockers, and sentiment.
    func summarize(thread: EmailThread, policy: PolicyBundle) async throws -> ThreadSummary
    /// Pull commitments, deadlines, approvals, and implied tasks from a single message.
    func extractActions(from email: SecureEmail, policy: PolicyBundle) async throws -> [ExtractedEmailAction]
}

// MARK: - Capability 4: Tone-Aware Drafting

public protocol EmailToneAnalyzer: Sendable {
    var isLocalOnly: Bool { get }
    /// Analyze the tone of a draft, optionally comparing against the recipient's known voice profile.
    func analyzeTone(draftBody: String, subject: String, recipientProfile: SenderProfile?) async -> EmailToneAnalysis
    /// Detect explicit and implicit commitments in a body of text.
    func detectCommitments(in text: String) async -> [DetectedCommitment]
}

// MARK: - Capability 5: Phishing & Risk Detection

public protocol EmailRiskDetector: Sendable {
    /// True for all current implementations; PHI/Restricted emails must never be sent to a remote model.
    var isLocalOnly: Bool { get }
    /// Assess phishing, BEC, urgency manipulation, impersonation, prompt injection, and social engineering.
    /// Attaches CitedControl citations (HIPAA §164.502, NIST AC-3, GDPR Art. 9) whenever sensitivity == .restricted.
    func assess(email: SecureEmail, senderProfile: SenderProfile?, policy: PolicyBundle) async throws -> EmailRiskAssessment
    /// Fast, synchronous-equivalent check for adversarial prompt injection payloads embedded in email bodies.
    func scanForPromptInjection(body: String) async -> Bool
}

// MARK: - Capability 6: Organizational Memory & Relationship Intelligence

public protocol SenderProfileStore: Sendable {
    /// Return the cached or freshly computed profile for a sender within a tenant.
    func profile(for email: String, tenantId: String) async -> SenderProfile?
    /// Persist an updated sender profile (local storage only; never transmitted without explicit consent).
    func updateProfile(_ profile: SenderProfile, tenantId: String) async throws
    /// Number of graph hops between the authenticated actor and the target email address.
    /// Returns nil when the target is not found in the org graph.
    func orgGraphDistance(from actorId: String, to targetEmail: String, tenantId: String) async -> Int?
}

// MARK: - Capability 7: Privacy & Local Processing Metadata

/// Records where a specific analysis ran and the policy reason that drove the routing decision.
/// This is not a toggle — the orchestrator derives it from sensitivity + policy rules and attaches it
/// to every EmailIntelligenceResult for full auditability.
public struct ProcessingLocation: Sendable {
    public enum Location: String, Sendable {
        case onDevice
        case cloudAI
    }
    public let location: Location
    /// Human-readable explanation surfaced in audit logs, e.g.
    /// "PHI content forces on-device processing per HIPAA §164.502" or
    /// "Enterprise policy permits cloud AI for INTERNAL sensitivity."
    public let reason: String

    public init(location: Location, reason: String) {
        self.location = location
        self.reason = reason
    }
}

// MARK: - Capability 8: Multi-Agent Inbox Orchestration

public protocol EmailOrchestrator: Sendable {
    /// Run all intelligence capabilities (triage, risk, tone, sender profile) on a single email.
    func analyze(email: SecureEmail, session: XQSession, policy: PolicyBundle) async throws -> EmailIntelligenceResult
    /// Autonomously triage an entire inbox; returns results sorted critical → noise.
    func autonomousTriage(inbox: [SecureEmail], session: XQSession, policy: PolicyBundle) async throws -> [EmailTriageResult]
    /// Generate a context-aware reply draft, subject to cloud-AI policy gating.
    func suggestReply(for email: SecureEmail, userContext: String, policy: PolicyBundle) async throws -> String
}
