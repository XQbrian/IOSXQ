import Foundation

// MARK: - Capability 1: Deep Content Understanding

protocol ContentAnalyzer: Sendable {
    // True for PHI/Restricted; the orchestrator checks this before routing to any cloud provider.
    var isLocalOnly: Bool { get }
    func analyzeContent(_ file: SecureFile, session: XQSession) async throws -> DocumentContentProfile
}

// MARK: - Capability 2: Data Classification

protocol FileClassifier: Sendable {
    func classify(_ file: SecureFile, session: XQSession) async throws -> FileClassificationLabel
}

// MARK: - Capability 3: Policy Enforcement

protocol FilePolicyEnforcer: Sendable {
    func enforce(policy: PolicyBundle, for file: SecureFile) -> FilePolicyDecision
}

// MARK: - Capability 4: Risk Discovery

protocol FileRiskScanner: Sendable {
    // Risk scanning involves evaluating raw credential/PHI signals; must never be routed to cloud.
    var isLocalOnly: Bool { get }
    func scanForRisks(_ file: SecureFile, session: XQSession) async throws -> [FileRiskFinding]
}

// MARK: - Capability 5: Semantic Search

protocol SemanticSearchProvider: Sendable {
    func search(query: String, in files: [SecureFile], session: XQSession) async throws -> [SemanticSearchResult]
}

// MARK: - Capability 6: Workflow Extraction

protocol WorkflowExtractor: Sendable {
    func extractWorkflow(_ file: SecureFile, session: XQSession) async throws -> ExtractedFileWorkflow
}

// MARK: - Capability 7: Threat Analysis

protocol FileThreatAnalyzer: Sendable {
    // Macro, steganography, and prompt-injection scans run on raw bytes — never sent to cloud.
    var isLocalOnly: Bool { get }
    func analyzeThreat(_ file: SecureFile, session: XQSession) async throws -> FileThreatReport
}

// MARK: - Capability 8: Data Lineage

protocol DataLineageService: Sendable {
    func lineageFor(_ fileId: UUID, session: XQSession) async throws -> DataLineageRecord
    func recordEvent(_ event: LineageEvent, for fileId: UUID, session: XQSession) async throws
}

// MARK: - Capability 9: Privacy-Preserving Analysis

protocol PrivacyAnalyzer: Sendable {
    func analyzePrivacy(
        _ file: SecureFile,
        policy: PolicyBundle,
        session: XQSession
    ) async throws -> PrivacyAnalysisResult
}

// MARK: - Capability 10: Autonomous File Agent

protocol FileAgentOrchestrator: Sendable {
    func proposeTask(_ task: FileAgentTask) async throws -> FileAgentTask
    func authorizeAndExecute(taskId: UUID, authorizedBy: String, session: XQSession) async throws -> FileAgentTask
    func pendingTasks(session: XQSession) async throws -> [FileAgentTask]
}
