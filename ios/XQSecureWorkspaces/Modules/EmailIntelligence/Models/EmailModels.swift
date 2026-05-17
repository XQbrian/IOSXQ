import Foundation
import XQCore

// MARK: - Core Email Types

public struct SecureEmail: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let messageId: String
    public let threadId: String
    public let subject: String
    public let senderEmail: String
    public let senderName: String
    public let recipientEmails: [String]
    public let ccEmails: [String]
    public let bodyPreview: String
    public let encryptedPayloadId: String
    public let sensitivity: SensitivityLevel
    public let receivedAt: Date
    public let isRead: Bool
    public let hasAttachments: Bool

    public init(id: UUID, messageId: String, threadId: String, subject: String,
                senderEmail: String, senderName: String, recipientEmails: [String],
                ccEmails: [String], bodyPreview: String, encryptedPayloadId: String,
                sensitivity: SensitivityLevel, receivedAt: Date, isRead: Bool, hasAttachments: Bool) {
        self.id = id
        self.messageId = messageId
        self.threadId = threadId
        self.subject = subject
        self.senderEmail = senderEmail
        self.senderName = senderName
        self.recipientEmails = recipientEmails
        self.ccEmails = ccEmails
        self.bodyPreview = bodyPreview
        self.encryptedPayloadId = encryptedPayloadId
        self.sensitivity = sensitivity
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.hasAttachments = hasAttachments
    }
}

public struct SecureEmailAttachment: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let filename: String
    public let mimeType: String
    public let sizeBytes: Int64
    public let encryptedPayloadId: String
    public let sensitivity: SensitivityLevel

    public init(id: UUID, filename: String, mimeType: String, sizeBytes: Int64,
                encryptedPayloadId: String, sensitivity: SensitivityLevel) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.encryptedPayloadId = encryptedPayloadId
        self.sensitivity = sensitivity
    }
}

public struct EmailThread: Identifiable, Sendable {
    public let id: String
    public let subject: String
    public let participants: [String]
    public let messageCount: Int
    public let latestAt: Date
    public let sensitivity: SensitivityLevel
    public let messages: [SecureEmail]
    public let summary: ThreadSummary?

    public init(id: String, subject: String, participants: [String], messageCount: Int,
                latestAt: Date, sensitivity: SensitivityLevel, messages: [SecureEmail], summary: ThreadSummary?) {
        self.id = id
        self.subject = subject
        self.participants = participants
        self.messageCount = messageCount
        self.latestAt = latestAt
        self.sensitivity = sensitivity
        self.messages = messages
        self.summary = summary
    }
}

// MARK: - Priority

public enum EmailPriority: Int, Comparable, CaseIterable, Sendable {
    case critical = 0
    case action = 1
    case fyi = 2
    case noise = 3

    public static func < (lhs: EmailPriority, rhs: EmailPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .critical: return "Critical"
        case .action:   return "Action Required"
        case .fyi:      return "FYI"
        case .noise:    return "Noise"
        }
    }
}

public struct EmailTriageResult: Identifiable, Sendable {
    public let id: UUID
    public let emailId: UUID
    public let priority: EmailPriority
    public let priorityReason: String
    public let extractedActionCount: Int
    public let hasDeadline: Bool
    public let deadlineAt: Date?
    public let senderImportance: SenderImportance

    public init(emailId: UUID, priority: EmailPriority, priorityReason: String,
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

public enum SenderImportance: String, CaseIterable, Sendable {
    case executive
    case directReport
    case peer
    case externalPartner
    case externalUnknown
    case automated
}

// MARK: - Risk Detection

public enum EmailRiskLevel: String, CaseIterable, Comparable, Sendable {
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

    public static func < (lhs: EmailRiskLevel, rhs: EmailRiskLevel) -> Bool {
        lhs.order < rhs.order
    }
}

public struct EmailRiskSignal: Identifiable, Sendable {
    public let id: UUID
    public let type: SignalType
    public let description: String
    public let confidence: Double

    public enum SignalType: String, CaseIterable, Sendable {
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

    public init(id: UUID = UUID(), type: SignalType, description: String, confidence: Double) {
        self.id = id
        self.type = type
        self.description = description
        self.confidence = confidence
    }
}

public struct EmailRiskAssessment: Sendable {
    public let emailId: UUID
    public let overallRisk: EmailRiskLevel
    /// Normalized 0–100 composite score.
    public let riskScore: Int
    public let signals: [EmailRiskSignal]
    public let isPhishing: Bool
    public let isBEC: Bool
    public let hasUrgencyManipulation: Bool
    public let hasImpersonation: Bool
    public let hasSuspiciousLinks: Bool
    public let hasPromptInjection: Bool
    /// Controls cited when PHI/Restricted email is assessed (HIPAA §164.502, NIST AC-3, GDPR Art. 9).
    public let citedControls: [CitedControl]
    public let recommendedAction: EmailRiskAction

    public init(emailId: UUID, overallRisk: EmailRiskLevel, riskScore: Int, signals: [EmailRiskSignal],
                isPhishing: Bool, isBEC: Bool, hasUrgencyManipulation: Bool, hasImpersonation: Bool,
                hasSuspiciousLinks: Bool, hasPromptInjection: Bool, citedControls: [CitedControl],
                recommendedAction: EmailRiskAction) {
        self.emailId = emailId
        self.overallRisk = overallRisk
        self.riskScore = riskScore
        self.signals = signals
        self.isPhishing = isPhishing
        self.isBEC = isBEC
        self.hasUrgencyManipulation = hasUrgencyManipulation
        self.hasImpersonation = hasImpersonation
        self.hasSuspiciousLinks = hasSuspiciousLinks
        self.hasPromptInjection = hasPromptInjection
        self.citedControls = citedControls
        self.recommendedAction = recommendedAction
    }
}

public enum EmailRiskAction: String, CaseIterable, Sendable {
    case allow
    case warn
    case quarantine
    case block
    case requireConfirmation
}

// MARK: - Thread Intelligence

public enum ThreadSentiment: String, CaseIterable, Sendable {
    case positive
    case neutral
    case tense
    case urgent
    case escalating
}

public struct ExtractedEmailAction: Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let assignee: String?
    public let deadline: Date?
    public let type: ActionType
    public let confidence: Double
    public let sourceMessageId: String

    public enum ActionType: String, CaseIterable, Sendable {
        case commitment
        case request
        case approval
        case reminder
        case followUp
        case procurementAction
        case legalReview
    }

    public init(id: UUID = UUID(), text: String, assignee: String?, deadline: Date?,
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

public struct ThreadSummary: Sendable {
    public let threadId: String
    public let oneSentenceSummary: String
    public let keyDecisions: [String]
    public let actionItems: [ExtractedEmailAction]
    public let unresolvedIssues: [String]
    public let blockers: [String]
    public let sentiment: ThreadSentiment
    public let messageCount: Int
    public let compressedFromWordCount: Int
    public let compressedToWordCount: Int
    /// False when sensitivity constraints forced local-only processing.
    public let wasCloudProcessed: Bool

    public init(threadId: String, oneSentenceSummary: String, keyDecisions: [String],
                actionItems: [ExtractedEmailAction], unresolvedIssues: [String], blockers: [String],
                sentiment: ThreadSentiment, messageCount: Int, compressedFromWordCount: Int,
                compressedToWordCount: Int, wasCloudProcessed: Bool) {
        self.threadId = threadId
        self.oneSentenceSummary = oneSentenceSummary
        self.keyDecisions = keyDecisions
        self.actionItems = actionItems
        self.unresolvedIssues = unresolvedIssues
        self.blockers = blockers
        self.sentiment = sentiment
        self.messageCount = messageCount
        self.compressedFromWordCount = compressedFromWordCount
        self.compressedToWordCount = compressedToWordCount
        self.wasCloudProcessed = wasCloudProcessed
    }
}

// MARK: - Tone Analysis

public enum EmailTone: String, CaseIterable, Sendable {
    case veryFormal
    case formal
    case neutral
    case casual
    case veryCasual
    case aggressive
    case passive
}

public struct ToneSuggestion: Sendable {
    public let type: SuggestionType
    public let description: String

    public enum SuggestionType: String, CaseIterable, Sendable {
        case tooFormal
        case tooCasual
        case tooLong
        case missingCallToAction
        case unclearDeadline
        case ambiguousCommitment
    }

    public init(type: SuggestionType, description: String) {
        self.type = type
        self.description = description
    }
}

public struct DetectedCommitment: Sendable {
    public let text: String
    public let deliverable: String
    public let deadline: Date?
    public let isExplicit: Bool

    public init(text: String, deliverable: String, deadline: Date?, isExplicit: Bool) {
        self.text = text
        self.deliverable = deliverable
        self.deadline = deadline
        self.isExplicit = isExplicit
    }
}

public struct EmailToneAnalysis: Sendable {
    public let emailId: UUID
    public let tone: EmailTone
    /// 0 = extremely casual, 100 = maximally formal.
    public let formalityScore: Int
    /// 0 = no urgency, 100 = extreme urgency.
    public let urgencyScore: Int
    /// -100 = very negative, 0 = neutral, +100 = very positive.
    public let sentimentScore: Int
    public let matchesVoiceProfile: Bool
    public let suggestions: [ToneSuggestion]
    public let commitments: [DetectedCommitment]

    public init(emailId: UUID, tone: EmailTone, formalityScore: Int, urgencyScore: Int,
                sentimentScore: Int, matchesVoiceProfile: Bool, suggestions: [ToneSuggestion],
                commitments: [DetectedCommitment]) {
        self.emailId = emailId
        self.tone = tone
        self.formalityScore = formalityScore
        self.urgencyScore = urgencyScore
        self.sentimentScore = sentimentScore
        self.matchesVoiceProfile = matchesVoiceProfile
        self.suggestions = suggestions
        self.commitments = commitments
    }
}

// MARK: - Organizational Memory

public enum SenderRelationship: String, CaseIterable, Sendable {
    case manager
    case directReport
    case peer
    case crossFunctional
    case externalPartner
    case client
    case vendor
    case unknown
}

public enum EscalationPattern: String, CaseIterable, Sendable {
    case neverEscalates
    case escalatesSlowly
    case escalatesQuickly
    case sendsToExecutives
}

public struct SenderProfile: Identifiable, Sendable {
    public let id: UUID
    public let email: String
    public let displayName: String
    public let orgGraphDistance: Int
    public let relationship: SenderRelationship
    public let averageResponseHours: Double
    public let escalationTendency: EscalationPattern
    public let projectAssociations: [String]
    public let historicalSentiment: Double
    public let knownPatterns: [String]

    public init(id: UUID, email: String, displayName: String, orgGraphDistance: Int,
                relationship: SenderRelationship, averageResponseHours: Double,
                escalationTendency: EscalationPattern, projectAssociations: [String],
                historicalSentiment: Double, knownPatterns: [String]) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.orgGraphDistance = orgGraphDistance
        self.relationship = relationship
        self.averageResponseHours = averageResponseHours
        self.escalationTendency = escalationTendency
        self.projectAssociations = projectAssociations
        self.historicalSentiment = historicalSentiment
        self.knownPatterns = knownPatterns
    }
}

// MARK: - Composite Intelligence Result

public struct EmailIntelligenceResult: Sendable {
    public let emailId: UUID
    public let triage: EmailTriageResult
    public let riskAssessment: EmailRiskAssessment
    public let toneAnalysis: EmailToneAnalysis?
    public let senderProfile: SenderProfile?
    public let processedAt: Date
    public let processingMs: Int
    public let wasCloudProcessed: Bool
    /// Key: capability name, Value: model version string.
    public let modelVersions: [String: String]

    public init(emailId: UUID, triage: EmailTriageResult, riskAssessment: EmailRiskAssessment,
                toneAnalysis: EmailToneAnalysis?, senderProfile: SenderProfile?, processedAt: Date,
                processingMs: Int, wasCloudProcessed: Bool, modelVersions: [String: String]) {
        self.emailId = emailId
        self.triage = triage
        self.riskAssessment = riskAssessment
        self.toneAnalysis = toneAnalysis
        self.senderProfile = senderProfile
        self.processedAt = processedAt
        self.processingMs = processingMs
        self.wasCloudProcessed = wasCloudProcessed
        self.modelVersions = modelVersions
    }
}

// MARK: - Audit

public enum EmailAuditEventType: String, Sendable {
    case emailTriaged
    case phishingDetected
    case phishingBlocked
    case actionExtracted
    case emailSent
    case emailRiskBlocked
    case toneAnalyzed
}
