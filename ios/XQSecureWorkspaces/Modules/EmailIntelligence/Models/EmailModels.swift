import Foundation

// MARK: - Core Email Types

struct SecureEmail: Identifiable, Hashable, Sendable {
    let id: UUID
    let messageId: String
    let threadId: String
    let subject: String
    let senderEmail: String
    let senderName: String
    let recipientEmails: [String]
    let ccEmails: [String]
    let bodyPreview: String
    let encryptedPayloadId: String
    let sensitivity: SensitivityLevel
    let receivedAt: Date
    let isRead: Bool
    let hasAttachments: Bool
}

struct SecureEmailAttachment: Identifiable, Hashable, Sendable {
    let id: UUID
    let filename: String
    let mimeType: String
    let sizeBytes: Int64
    let encryptedPayloadId: String
    let sensitivity: SensitivityLevel
}

struct EmailThread: Identifiable, Sendable {
    let id: String
    let subject: String
    let participants: [String]
    let messageCount: Int
    let latestAt: Date
    let sensitivity: SensitivityLevel
    let messages: [SecureEmail]
    let summary: ThreadSummary?
}

// MARK: - Priority

enum EmailPriority: Int, Comparable, CaseIterable, Sendable {
    case critical = 0
    case action = 1
    case fyi = 2
    case noise = 3

    static func < (lhs: EmailPriority, rhs: EmailPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .critical: return "Critical"
        case .action:   return "Action Required"
        case .fyi:      return "FYI"
        case .noise:    return "Noise"
        }
    }
}

struct EmailTriageResult: Identifiable, Sendable {
    let id: UUID
    let emailId: UUID
    let priority: EmailPriority
    let priorityReason: String
    let extractedActionCount: Int
    let hasDeadline: Bool
    let deadlineAt: Date?
    let senderImportance: SenderImportance

    init(emailId: UUID, priority: EmailPriority, priorityReason: String,
         extractedActionCount: Int, hasDeadline: Bool, deadlineAt: Date?,
         senderImportance: SenderImportance) {
        self.id = UUID()
        self.emailId = emailId
        self.priority = priority
        self.priorityReason = priorityReason
        self.extractedActionCount = extractedActionCount
        self.hasDeadline = hasDeadline
        self.deadlineAt = deadlineAt
        self.senderImportance = senderImportance
    }
}

enum SenderImportance: String, CaseIterable, Sendable {
    case executive
    case directReport
    case peer
    case externalPartner
    case externalUnknown
    case automated
}

// MARK: - Risk Detection

enum EmailRiskLevel: String, CaseIterable, Comparable, Sendable {
    case safe
    case low
    case medium
    case high
    case critical

    private var order: Int {
        switch self {
        case .safe:     return 0
        case .low:      return 1
        case .medium:   return 2
        case .high:     return 3
        case .critical: return 4
        }
    }

    static func < (lhs: EmailRiskLevel, rhs: EmailRiskLevel) -> Bool {
        lhs.order < rhs.order
    }
}

struct EmailRiskSignal: Identifiable, Sendable {
    let id: UUID
    let type: SignalType
    let description: String
    let confidence: Double

    enum SignalType: String, CaseIterable, Sendable {
        case urgencyManipulation
        case senderSpoofing
        case domainAnomaly
        case unusualRelationshipPattern
        case impersonation
        case maliciousLink
        case promptInjection
        case invoiceFraud
        case socialEngineering
        case behavioralAnomaly
    }

    init(id: UUID = UUID(), type: SignalType, description: String, confidence: Double) {
        self.id = id
        self.type = type
        self.description = description
        self.confidence = confidence
    }
}

struct EmailRiskAssessment: Sendable {
    let emailId: UUID
    let overallRisk: EmailRiskLevel
    /// Normalized 0–100 composite score.
    let riskScore: Int
    let signals: [EmailRiskSignal]
    let isPhishing: Bool
    let isBEC: Bool
    let hasUrgencyManipulation: Bool
    let hasImpersonation: Bool
    let hasSuspiciousLinks: Bool
    let hasPromptInjection: Bool
    /// Controls cited when PHI/Restricted email is assessed (HIPAA §164.502, NIST AC-3, GDPR Art. 9).
    let citedControls: [CitedControl]
    let recommendedAction: EmailRiskAction
}

enum EmailRiskAction: String, CaseIterable, Sendable {
    case allow
    case warn
    case quarantine
    case block
    case requireConfirmation
}

// MARK: - Thread Intelligence

enum ThreadSentiment: String, CaseIterable, Sendable {
    case positive
    case neutral
    case tense
    case urgent
    case escalating
}

struct ExtractedEmailAction: Identifiable, Sendable {
    let id: UUID
    let text: String
    let assignee: String?
    let deadline: Date?
    let type: ActionType
    let confidence: Double
    let sourceMessageId: String

    enum ActionType: String, CaseIterable, Sendable {
        case commitment
        case request
        case approval
        case reminder
        case followUp
        case procurementAction
        case legalReview
    }

    init(id: UUID = UUID(), text: String, assignee: String?, deadline: Date?,
         type: ActionType, confidence: Double, sourceMessageId: String) {
        self.id = id
        self.text = text
        self.assignee = assignee
        self.deadline = deadline
        self.type = type
        self.confidence = confidence
        self.sourceMessageId = sourceMessageId
    }
}

struct ThreadSummary: Sendable {
    let threadId: String
    let oneSentenceSummary: String
    let keyDecisions: [String]
    let actionItems: [ExtractedEmailAction]
    let unresolvedIssues: [String]
    let blockers: [String]
    let sentiment: ThreadSentiment
    let messageCount: Int
    let compressedFromWordCount: Int
    let compressedToWordCount: Int
    /// False when sensitivity constraints forced local-only processing.
    let wasCloudProcessed: Bool
}

// MARK: - Tone Analysis

enum EmailTone: String, CaseIterable, Sendable {
    case veryFormal
    case formal
    case neutral
    case casual
    case veryCasual
    case aggressive
    case passive
}

struct ToneSuggestion: Sendable {
    let type: SuggestionType
    let description: String

    enum SuggestionType: String, CaseIterable, Sendable {
        case tooFormal
        case tooCasual
        case tooLong
        case missingCallToAction
        case unclearDeadline
        case ambiguousCommitment
    }
}

struct DetectedCommitment: Sendable {
    let text: String
    let deliverable: String
    let deadline: Date?
    let isExplicit: Bool
}

struct EmailToneAnalysis: Sendable {
    let emailId: UUID
    let tone: EmailTone
    /// 0 = extremely casual, 100 = maximally formal.
    let formalityScore: Int
    /// 0 = no urgency, 100 = extreme urgency.
    let urgencyScore: Int
    /// -100 = very negative, 0 = neutral, +100 = very positive.
    let sentimentScore: Int
    let matchesVoiceProfile: Bool
    let suggestions: [ToneSuggestion]
    let commitments: [DetectedCommitment]
}

// MARK: - Organizational Memory

enum SenderRelationship: String, CaseIterable, Sendable {
    case manager
    case directReport
    case peer
    case crossFunctional
    case externalPartner
    case client
    case vendor
    case unknown
}

enum EscalationPattern: String, CaseIterable, Sendable {
    case neverEscalates
    case escalatesSlowly
    case escalatesQuickly
    case sendsToExecutives
}

struct SenderProfile: Identifiable, Sendable {
    let id: UUID
    let email: String
    let displayName: String
    let orgGraphDistance: Int
    let relationship: SenderRelationship
    let averageResponseHours: Double
    let escalationTendency: EscalationPattern
    let projectAssociations: [String]
    let historicalSentiment: Double
    let knownPatterns: [String]
}

// MARK: - Composite Intelligence Result

struct EmailIntelligenceResult: Sendable {
    let emailId: UUID
    let triage: EmailTriageResult
    let riskAssessment: EmailRiskAssessment
    let toneAnalysis: EmailToneAnalysis?
    let senderProfile: SenderProfile?
    let processedAt: Date
    let processingMs: Int
    let wasCloudProcessed: Bool
    /// Key: capability name, Value: model version string.
    let modelVersions: [String: String]
}

// MARK: - Audit

enum EmailAuditEventType: String, Sendable {
    case emailTriaged
    case phishingDetected
    case phishingBlocked
    case actionExtracted
    case emailSent
    case emailRiskBlocked
    case toneAnalyzed
}
