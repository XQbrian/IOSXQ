import Foundation

protocol PolicyEngine: Sendable {
    var currentBundle: PolicyBundle? { get }

    func loadBundle(_ bundle: PolicyBundle) async throws
    func evaluate(operation: PolicyOperation, for file: SecureFile, actor: String) async -> PolicyDecision
    func rule(for sensitivity: SensitivityLevel) -> PolicyRule?
}

enum PolicyOperation {
    case openFile
    case shareExternally(recipientDomain: String)
    case shareInternally
    case uploadToCloud
    case exportToLocalFiles
    case screenshot
}

struct PolicyDecision {
    let allowed: Bool
    let enforcement: CitedControl.Enforcement
    let citedControls: [CitedControl]
    let requiredApprovalRole: String?
    let auditRequired: Bool
}
