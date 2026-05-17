import Foundation

@MainActor
final class FileIntelligenceViewModel: ObservableObject {

    @Published var contentProfile: DocumentContentProfile?
    @Published var classificationLabel: FileClassificationLabel?
    @Published var policyDecision: FilePolicyDecision?
    @Published var riskFindings: [FileRiskFinding] = []
    @Published var threatReport: FileThreatReport?
    @Published var lineage: DataLineageRecord?
    @Published var privacyResult: PrivacyAnalysisResult?
    @Published var workflowData: ExtractedFileWorkflow?
    @Published var pendingAgentTasks: [FileAgentTask] = []
    @Published var isAnalyzing: Bool = false
    @Published var analysisError: FileIntelligenceError?

    private let orchestrator: FileIntelligenceOrchestrator

    init(orchestrator: FileIntelligenceOrchestrator) {
        self.orchestrator = orchestrator
    }

    // MARK: - Analysis

    func analyze(file: SecureFile, policy: PolicyBundle, session: XQSession) async {
        isAnalyzing = true
        analysisError = nil

        do {
            let result = try await orchestrator.analyze(file, policy: policy, session: session)
            contentProfile     = result.contentProfile
            classificationLabel = result.classificationLabel
            policyDecision     = result.policyDecision
            riskFindings       = result.riskFindings
            threatReport       = result.threatReport
            lineage            = result.lineage
            privacyResult      = result.privacyResult
            workflowData       = result.workflowData
        } catch let error as FileIntelligenceError {
            analysisError = error
        } catch {
            // Non-FileIntelligenceError failures are surfaced via policyBlock to preserve typed contract.
            analysisError = .classificationFailed
        }

        isAnalyzing = false
    }

    // MARK: - Agent Task Authorization

    func authorizeAgentTask(_ taskId: UUID, session: XQSession) async {
        do {
            let completed = try await orchestrator.authorizeAndExecute(
                taskId: taskId,
                authorizedBy: session.userId,
                session: session
            )
            // Refresh pending list; completed task is removed.
            let allPending = try await orchestrator.pendingTasks(session: session)
            pendingAgentTasks = allPending
        } catch let error as FileIntelligenceError {
            analysisError = error
        } catch {
            analysisError = .agentTaskRequiresApproval
        }
    }

    // MARK: - Computed Properties

    // Severity weights: critical=30, high=15, medium=5, low=1. Capped at 100.
    var orgRiskScore: Int {
        let raw = riskFindings.reduce(0) { sum, finding in
            switch finding.severity {
            case .critical: return sum + 30
            case .high:     return sum + 15
            case .medium:   return sum + 5
            case .low:      return sum + 1
            }
        }
        return min(raw, 100)
    }
}
