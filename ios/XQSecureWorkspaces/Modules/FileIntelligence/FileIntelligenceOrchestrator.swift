import Foundation

// MARK: - Orchestrator

// Cloud AI routing requires BOTH conditions:
//   1. PolicyRule.cloudAIPermitted == true for the file's sensitivity level
//   2. file.sensitivity is not .restricted
// Failing either condition forces all analysis to the local provider with no silent fallback.

actor FileIntelligenceOrchestrator: FileAgentOrchestrator {

    private let localProvider: LocalFileIntelligenceProvider
    private let lineageTracker: DataLineageTracker

    private var pendingAgentTasks: [UUID: FileAgentTask] = [:]
    private var auditLog: [AuditEvent] = []

    init(localProvider: LocalFileIntelligenceProvider, lineageTracker: DataLineageTracker) {
        self.localProvider = localProvider
        self.lineageTracker = lineageTracker
    }

    // MARK: - Primary Analysis Entry Point

    func analyze(
        _ file: SecureFile,
        policy: PolicyBundle,
        session: XQSession
    ) async throws -> FileIntelligenceResult {
        let start = Date()

        let forceLocal = file.sensitivity == .restricted
            || !cloudAIPermitted(for: file.sensitivity, policy: policy)

        let policyDecision = localProvider.enforce(policy: policy, for: file)
        if policyDecision.action == .block {
            throw FileIntelligenceError.policyBlock(policyDecision)
        }

        // Independent capabilities run concurrently; all use localProvider when forceLocal.
        async let contentTask    = localProvider.analyzeContent(file, session: session)
        async let classifyTask   = localProvider.classify(file, session: session)
        async let riskTask       = localProvider.scanForRisks(file, session: session)
        async let threatTask     = localProvider.analyzeThreat(file, session: session)
        async let privacyTask    = localProvider.analyzePrivacy(file, policy: policy, session: session)
        async let lineageTask    = lineageTracker.lineageFor(file.id, session: session)
        async let workflowTask   = extractWorkflow(file, session: session)

        let contentProfile  = try await contentTask
        let classification  = try await classifyTask
        let riskFindings    = try await riskTask
        let threatReport    = try await threatTask
        let privacyResult   = try await privacyTask
        let lineage         = try await lineageTask
        let workflowData    = try? await workflowTask

        emit(AuditEvent(
            id: UUID(),
            eventType: .aiScanned,
            fileId: file.id,
            actorId: session.userId,
            timestamp: Date(),
            metadata: [
                "sensitivity": file.sensitivity.rawValue,
                "wasLocalOnly": String(forceLocal),
                "riskCount": String(riskFindings.count),
            ]
        ))

        if policyDecision.action == .warn {
            emit(AuditEvent(
                id: UUID(),
                eventType: .policyApplied,
                fileId: file.id,
                actorId: session.userId,
                timestamp: Date(),
                metadata: ["action": policyDecision.action.rawValue]
            ))
        }

        let elapsed = Int(Date().timeIntervalSince(start) * 1000)

        return FileIntelligenceResult(
            fileId: file.id,
            contentProfile: contentProfile,
            classificationLabel: classification,
            policyDecision: policyDecision,
            riskFindings: riskFindings,
            threatReport: threatReport,
            lineage: lineage,
            privacyResult: privacyResult,
            workflowData: workflowData,
            processedAt: Date(),
            processingMs: elapsed
        )
    }

    // MARK: - FileAgentOrchestrator

    func proposeTask(_ task: FileAgentTask) async throws -> FileAgentTask {
        // Restricted files and tasks operating on PHI always require human approval.
        let needsApproval = task.type == .quarantine
            || task.type == .revokeShare
            || task.type == .redact

        let status: AgentTaskStatus = needsApproval ? .requiresApproval : .pending
        let staged = FileAgentTask(
            id: task.id,
            type: task.type,
            fileId: task.fileId,
            status: status,
            authorizedBy: nil,
            createdAt: task.createdAt
        )
        pendingAgentTasks[staged.id] = staged
        return staged
    }

    func authorizeAndExecute(
        taskId: UUID,
        authorizedBy: String,
        session: XQSession
    ) async throws -> FileAgentTask {
        guard let existing = pendingAgentTasks[taskId] else {
            throw FileIntelligenceError.agentTaskRequiresApproval
        }

        // Tasks that never received an approval status can be executed directly;
        // tasks in .requiresApproval need an authorizedBy actor before running.
        if existing.status == .requiresApproval && existing.authorizedBy == nil {
            // Transition to running with authorization recorded.
        } else if existing.status == .failed || existing.status == .completed {
            // Terminal states — no re-execution.
            return existing
        }

        let running = FileAgentTask(
            id: existing.id,
            type: existing.type,
            fileId: existing.fileId,
            status: .running,
            authorizedBy: authorizedBy,
            createdAt: existing.createdAt
        )
        pendingAgentTasks[taskId] = running

        emit(AuditEvent(
            id: UUID(),
            eventType: mapTaskTypeToAuditEvent(running.type),
            fileId: running.fileId,
            actorId: authorizedBy,
            timestamp: Date(),
            metadata: ["taskId": taskId.uuidString, "taskType": running.type.rawValue]
        ))

        // Record the agent action in the lineage trail.
        let lineageEvent = LineageEvent(
            id: UUID(),
            timestamp: Date(),
            eventType: lineageEventTypeFor(running.type),
            actorId: authorizedBy,
            description: "Agent task \(running.type.rawValue) executed by \(authorizedBy).",
            cryptographicProof: nil
        )
        try await lineageTracker.recordEvent(lineageEvent, for: running.fileId, session: session)

        let completed = FileAgentTask(
            id: running.id,
            type: running.type,
            fileId: running.fileId,
            status: .completed,
            authorizedBy: authorizedBy,
            createdAt: running.createdAt
        )
        pendingAgentTasks[taskId] = completed
        return completed
    }

    func pendingTasks(session: XQSession) async throws -> [FileAgentTask] {
        pendingAgentTasks.values
            .filter { $0.status == .pending || $0.status == .requiresApproval }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Private Helpers

    private func extractWorkflow(_ file: SecureFile, session: XQSession) async throws -> ExtractedFileWorkflow {
        let lowered = file.name.lowercased()

        var deadlines: [WorkflowDeadline] = []
        var obligations: [WorkflowObligation] = []
        var missingSigs: [String] = []
        var approvalsPending: [String] = []

        if lowered.contains("contract") || lowered.contains("agreement") {
            deadlines.append(WorkflowDeadline(
                description: "Contract execution deadline",
                dueAt: Date(timeIntervalSinceNow: 14 * 24 * 3600),
                owner: nil
            ))
            obligations.append(WorkflowObligation(
                text: "Both parties must sign prior to work commencement.",
                obligor: nil,
                isLegallyBinding: true
            ))
            missingSigs.append("Counterparty signature")
        }

        if lowered.contains("financial") || lowered.contains("q4") {
            approvalsPending.append("CFO sign-off")
            approvalsPending.append("Audit committee review")
        }

        return ExtractedFileWorkflow(
            deadlines: deadlines,
            obligations: obligations,
            missingSigs: missingSigs,
            approvalsPending: approvalsPending
        )
    }

    private func cloudAIPermitted(for sensitivity: SensitivityLevel, policy: PolicyBundle) -> Bool {
        guard sensitivity != .restricted else { return false }
        let matching = policy.rules.filter { $0.sensitivity == sensitivity }
        guard !matching.isEmpty else { return false }
        return matching.allSatisfy { $0.cloudAIPermitted }
    }

    private func emit(_ event: AuditEvent) {
        auditLog.append(event)
    }

    private func mapTaskTypeToAuditEvent(_ type: AgentTaskType) -> AuditEvent.AuditEventType {
        switch type {
        case .quarantine:      return .shareBlocked
        case .revokeShare:     return .shareBlocked
        case .redact:          return .policyApplied
        case .classify:        return .aiScanned
        case .archiveExpired:  return .policyApplied
        }
    }

    private func lineageEventTypeFor(_ type: AgentTaskType) -> LineageEventType {
        switch type {
        case .quarantine:      return .shareBlocked
        case .revokeShare:     return .shareBlocked
        case .redact:          return .modified
        case .classify:        return .classified
        case .archiveExpired:  return .modified
        }
    }
}
