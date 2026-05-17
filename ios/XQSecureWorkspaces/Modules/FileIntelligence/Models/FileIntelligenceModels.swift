import Foundation
import XQCore

// MARK: - Capability 1: Deep Content Understanding

public struct DocumentContentProfile: Sendable {
    public let docType: String
    public let language: String
    public let entityCount: Int
    public let extractedObligations: [String]
    public let keyTopics: [String]
    public let processingMs: Int
    public let wasLocalOnly: Bool

    public init(docType: String, language: String, entityCount: Int, extractedObligations: [String],
                keyTopics: [String], processingMs: Int, wasLocalOnly: Bool) {
        self.docType = docType
        self.language = language
        self.entityCount = entityCount
        self.extractedObligations = extractedObligations
        self.keyTopics = keyTopics
        self.processingMs = processingMs
        self.wasLocalOnly = wasLocalOnly
    }
}

// MARK: - Capability 2: Data Classification

public struct FileClassificationLabel: Sendable {
    public let sensitivity: SensitivityLevel
    public let aiConfidence: Float
    public let triggerEntities: [AIEntity]
    public let appliedRules: [String]

    public init(sensitivity: SensitivityLevel, aiConfidence: Float,
                triggerEntities: [AIEntity], appliedRules: [String]) {
        self.sensitivity = sensitivity
        self.aiConfidence = aiConfidence
        self.triggerEntities = triggerEntities
        self.appliedRules = appliedRules
    }
}

// MARK: - Capability 3: Policy Enforcement

public enum PolicyAction: String, Sendable {
    case allow
    case warn
    case block
    case quarantine
}

public struct FilePolicyDecision: Sendable {
    public let action: PolicyAction
    public let appliedRules: [PolicyRule]
    public let citedControls: [CitedControl]
    public let requiresApproval: Bool

    public init(action: PolicyAction, appliedRules: [PolicyRule],
                citedControls: [CitedControl], requiresApproval: Bool) {
        self.action = action
        self.appliedRules = appliedRules
        self.citedControls = citedControls
        self.requiresApproval = requiresApproval
    }
}

// MARK: - Capability 4: Risk Discovery

public enum RiskCategory: String, Sendable {
    case credentialExposure
    case shadowAITraining
    case stalePermissions
    case policyDrift
    case promptInjection
    case steganography
}

public enum RiskSeverity: String, Sendable {
    case critical
    case high
    case medium
    case low
}

public struct FileRiskFinding: Identifiable, Sendable {
    public let id: UUID
    public let category: RiskCategory
    public let severity: RiskSeverity
    public let fileId: UUID
    public let description: String
    public let remediationSuggestion: String

    public init(id: UUID, category: RiskCategory, severity: RiskSeverity, fileId: UUID,
                description: String, remediationSuggestion: String) {
        self.id = id
        self.category = category
        self.severity = severity
        self.fileId = fileId
        self.description = description
        self.remediationSuggestion = remediationSuggestion
    }
}

// MARK: - Capability 5: Semantic Search

public struct SemanticSearchResult: Sendable {
    public let fileId: UUID
    public let relevanceScore: Float
    public let matchedSnippet: String
    public let highlightRanges: [NSRange]

    public init(fileId: UUID, relevanceScore: Float, matchedSnippet: String, highlightRanges: [NSRange]) {
        self.fileId = fileId
        self.relevanceScore = relevanceScore
        self.matchedSnippet = matchedSnippet
        self.highlightRanges = highlightRanges
    }
}

// MARK: - Capability 6: Workflow Extraction

public struct WorkflowDeadline: Sendable {
    public let description: String
    public let dueAt: Date
    public let owner: String?

    public init(description: String, dueAt: Date, owner: String?) {
        self.description = description
        self.dueAt = dueAt
        self.owner = owner
    }
}

public struct WorkflowObligation: Sendable {
    public let text: String
    public let obligor: String?
    public let isLegallyBinding: Bool

    public init(text: String, obligor: String?, isLegallyBinding: Bool) {
        self.text = text
        self.obligor = obligor
        self.isLegallyBinding = isLegallyBinding
    }
}

public struct ExtractedFileWorkflow: Sendable {
    public let deadlines: [WorkflowDeadline]
    public let obligations: [WorkflowObligation]
    public let missingSigs: [String]
    public let approvalsPending: [String]

    public init(deadlines: [WorkflowDeadline], obligations: [WorkflowObligation],
                missingSigs: [String], approvalsPending: [String]) {
        self.deadlines = deadlines
        self.obligations = obligations
        self.missingSigs = missingSigs
        self.approvalsPending = approvalsPending
    }
}

// MARK: - Capability 7: Threat Analysis

public enum ThreatLevel: String, Sendable {
    case clear
    case low
    case medium
    case high
    case critical
}

public struct FileThreatReport: Sendable {
    public let hasMacros: Bool
    public let promptInjectionRisk: Float
    public let steganographyRisk: Float
    public let aiTrainingRisk: Float
    public let shadowCopyCount: Int
    public let threatLevel: ThreatLevel

    public init(hasMacros: Bool, promptInjectionRisk: Float, steganographyRisk: Float,
                aiTrainingRisk: Float, shadowCopyCount: Int, threatLevel: ThreatLevel) {
        self.hasMacros = hasMacros
        self.promptInjectionRisk = promptInjectionRisk
        self.steganographyRisk = steganographyRisk
        self.aiTrainingRisk = aiTrainingRisk
        self.shadowCopyCount = shadowCopyCount
        self.threatLevel = threatLevel
    }
}

// MARK: - Capability 8: Data Lineage

public enum LineageEventType: String, Sendable {
    case created
    case modified
    case aiScanned
    case classified
    case shared
    case shareBlocked
    case outputGenerated
}

public struct LineageEvent: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: LineageEventType
    public let actorId: String?
    public let description: String
    // Hex-encoded SHA-256 of (fileId + eventType + timestamp ISO8601); nil for legacy events.
    public let cryptographicProof: String?

    public init(id: UUID, timestamp: Date, eventType: LineageEventType, actorId: String?,
                description: String, cryptographicProof: String?) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.actorId = actorId
        self.description = description
        self.cryptographicProof = cryptographicProof
    }
}

public struct DataLineageRecord: Sendable {
    public let fileId: UUID
    public let originHash: String
    public let events: [LineageEvent]
    public let outputFileIds: [UUID]

    public init(fileId: UUID, originHash: String, events: [LineageEvent], outputFileIds: [UUID]) {
        self.fileId = fileId
        self.originHash = originHash
        self.events = events
        self.outputFileIds = outputFileIds
    }
}

// MARK: - Capability 9: Privacy-Preserving Analysis

public struct ProcessingLocation: Sendable {
    public let isOnDevice: Bool
    public let modelVersion: String

    public init(isOnDevice: Bool, modelVersion: String) {
        self.isOnDevice = isOnDevice
        self.modelVersion = modelVersion
    }
}

public struct PrivacyAnalysisResult: Sendable {
    public let wasLocalOnly: Bool
    // cloudEgressBytes is structurally 0 for any local provider; declared so callers can assert it.
    public let cloudEgressBytes: Int
    public let entitiesRedacted: Int
    public let anonymizationApplied: Bool
    public let processingLocation: ProcessingLocation

    public init(
        wasLocalOnly: Bool,
        cloudEgressBytes: Int = 0,
        entitiesRedacted: Int,
        anonymizationApplied: Bool,
        processingLocation: ProcessingLocation
    ) {
        self.wasLocalOnly = wasLocalOnly
        self.cloudEgressBytes = cloudEgressBytes
        self.entitiesRedacted = entitiesRedacted
        self.anonymizationApplied = anonymizationApplied
        self.processingLocation = processingLocation
    }
}

// MARK: - Capability 10: Autonomous File Agent

public enum AgentTaskType: String, Sendable {
    case quarantine
    case revokeShare
    case redact
    case classify
    case archiveExpired
}

public enum AgentTaskStatus: String, Sendable {
    case pending
    case requiresApproval
    case running
    case completed
    case failed
}

public struct FileAgentTask: Identifiable, Sendable {
    public let id: UUID
    public let type: AgentTaskType
    public let fileId: UUID
    public let status: AgentTaskStatus
    public let authorizedBy: String?
    public let createdAt: Date

    public init(id: UUID, type: AgentTaskType, fileId: UUID, status: AgentTaskStatus,
                authorizedBy: String?, createdAt: Date) {
        self.id = id
        self.type = type
        self.fileId = fileId
        self.status = status
        self.authorizedBy = authorizedBy
        self.createdAt = createdAt
    }
}

// MARK: - Aggregate Result

public struct FileIntelligenceResult: Sendable {
    public let fileId: UUID
    public let contentProfile: DocumentContentProfile?
    public let classificationLabel: FileClassificationLabel?
    public let policyDecision: FilePolicyDecision?
    public let riskFindings: [FileRiskFinding]
    public let threatReport: FileThreatReport?
    public let lineage: DataLineageRecord?
    public let privacyResult: PrivacyAnalysisResult?
    public let workflowData: ExtractedFileWorkflow?
    public let processedAt: Date
    public let processingMs: Int

    public init(fileId: UUID, contentProfile: DocumentContentProfile?, classificationLabel: FileClassificationLabel?,
                policyDecision: FilePolicyDecision?, riskFindings: [FileRiskFinding], threatReport: FileThreatReport?,
                lineage: DataLineageRecord?, privacyResult: PrivacyAnalysisResult?,
                workflowData: ExtractedFileWorkflow?, processedAt: Date, processingMs: Int) {
        self.fileId = fileId
        self.contentProfile = contentProfile
        self.classificationLabel = classificationLabel
        self.policyDecision = policyDecision
        self.riskFindings = riskFindings
        self.threatReport = threatReport
        self.lineage = lineage
        self.privacyResult = privacyResult
        self.workflowData = workflowData
        self.processedAt = processedAt
        self.processingMs = processingMs
    }
}

// MARK: - Errors

public enum FileIntelligenceError: Error, LocalizedError, Sendable {
    case localOnlyViolation
    case policyBlock(FilePolicyDecision)
    case classificationFailed
    case lineageHashMismatch
    case agentTaskRequiresApproval

    public var errorDescription: String? {
        switch self {
        case .localOnlyViolation:
            return "CUI/PHI content must be processed on-device only; cloud routing is structurally prohibited."
        case .policyBlock(let decision):
            return "Policy engine blocked the operation: \(decision.action.rawValue). Rules: \(decision.appliedRules.map(\.name).joined(separator: ", "))."
        case .classificationFailed:
            return "AI classification could not determine a sensitivity label for the file."
        case .lineageHashMismatch:
            return "Cryptographic proof in LineageEvent does not match the computed hash; record integrity violated."
        case .agentTaskRequiresApproval:
            return "This agent task requires explicit human authorization before execution."
        }
    }
}
