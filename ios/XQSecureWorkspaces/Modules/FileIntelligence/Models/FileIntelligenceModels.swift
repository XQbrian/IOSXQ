import Foundation

// MARK: - Capability 1: Deep Content Understanding

struct DocumentContentProfile: Sendable {
    let docType: String
    let language: String
    let entityCount: Int
    let extractedObligations: [String]
    let keyTopics: [String]
    let processingMs: Int
    let wasLocalOnly: Bool
}

// MARK: - Capability 2: Data Classification

struct FileClassificationLabel: Sendable {
    let sensitivity: SensitivityLevel
    let aiConfidence: Float
    let triggerEntities: [AIEntity]
    let appliedRules: [String]
}

// MARK: - Capability 3: Policy Enforcement

enum PolicyAction: String, Sendable {
    case allow
    case warn
    case block
    case quarantine
}

struct FilePolicyDecision: Sendable {
    let action: PolicyAction
    let appliedRules: [PolicyRule]
    let citedControls: [CitedControl]
    let requiresApproval: Bool
}

// MARK: - Capability 4: Risk Discovery

enum RiskCategory: String, Sendable {
    case credentialExposure
    case shadowAITraining
    case stalePermissions
    case policyDrift
    case promptInjection
    case steganography
}

enum RiskSeverity: String, Sendable {
    case critical
    case high
    case medium
    case low
}

struct FileRiskFinding: Identifiable, Sendable {
    let id: UUID
    let category: RiskCategory
    let severity: RiskSeverity
    let fileId: UUID
    let description: String
    let remediationSuggestion: String
}

// MARK: - Capability 5: Semantic Search

struct SemanticSearchResult: Sendable {
    let fileId: UUID
    let relevanceScore: Float
    let matchedSnippet: String
    let highlightRanges: [NSRange]
}

// MARK: - Capability 6: Workflow Extraction

struct WorkflowDeadline: Sendable {
    let description: String
    let dueAt: Date
    let owner: String?
}

struct WorkflowObligation: Sendable {
    let text: String
    let obligor: String?
    let isLegallyBinding: Bool
}

struct ExtractedFileWorkflow: Sendable {
    let deadlines: [WorkflowDeadline]
    let obligations: [WorkflowObligation]
    let missingSigs: [String]
    let approvalsPending: [String]
}

// MARK: - Capability 7: Threat Analysis

enum ThreatLevel: String, Sendable {
    case clear
    case low
    case medium
    case high
    case critical
}

struct FileThreatReport: Sendable {
    let hasMacros: Bool
    let promptInjectionRisk: Float
    let steganographyRisk: Float
    let aiTrainingRisk: Float
    let shadowCopyCount: Int
    let threatLevel: ThreatLevel
}

// MARK: - Capability 8: Data Lineage

enum LineageEventType: String, Sendable {
    case created
    case modified
    case aiScanned
    case classified
    case shared
    case shareBlocked
    case outputGenerated
}

struct LineageEvent: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let eventType: LineageEventType
    let actorId: String?
    let description: String
    // Hex-encoded SHA-256 of (fileId + eventType + timestamp ISO8601); nil for legacy events.
    let cryptographicProof: String?
}

struct DataLineageRecord: Sendable {
    let fileId: UUID
    let originHash: String
    let events: [LineageEvent]
    let outputFileIds: [UUID]
}

// MARK: - Capability 9: Privacy-Preserving Analysis

struct ProcessingLocation: Sendable {
    let isOnDevice: Bool
    let modelVersion: String
}

struct PrivacyAnalysisResult: Sendable {
    let wasLocalOnly: Bool
    // cloudEgressBytes is structurally 0 for any local provider; declared so callers can assert it.
    let cloudEgressBytes: Int
    let entitiesRedacted: Int
    let anonymizationApplied: Bool
    let processingLocation: ProcessingLocation

    init(
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

enum AgentTaskType: String, Sendable {
    case quarantine
    case revokeShare
    case redact
    case classify
    case archiveExpired
}

enum AgentTaskStatus: String, Sendable {
    case pending
    case requiresApproval
    case running
    case completed
    case failed
}

struct FileAgentTask: Identifiable, Sendable {
    let id: UUID
    let type: AgentTaskType
    let fileId: UUID
    let status: AgentTaskStatus
    let authorizedBy: String?
    let createdAt: Date
}

// MARK: - Aggregate Result

struct FileIntelligenceResult: Sendable {
    let fileId: UUID
    let contentProfile: DocumentContentProfile?
    let classificationLabel: FileClassificationLabel?
    let policyDecision: FilePolicyDecision?
    let riskFindings: [FileRiskFinding]
    let threatReport: FileThreatReport?
    let lineage: DataLineageRecord?
    let privacyResult: PrivacyAnalysisResult?
    let workflowData: ExtractedFileWorkflow?
    let processedAt: Date
    let processingMs: Int
}

// MARK: - Errors

enum FileIntelligenceError: Error, LocalizedError, Sendable {
    case localOnlyViolation
    case policyBlock(FilePolicyDecision)
    case classificationFailed
    case lineageHashMismatch
    case agentTaskRequiresApproval

    var errorDescription: String? {
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
