import Foundation

public protocol PolicyEngine: Sendable {
    var currentBundle: PolicyBundle? { get }

    func loadBundle(_ bundle: PolicyBundle) async throws
    func evaluate(operation: PolicyOperation, for file: SecureFile, actor: String) async -> PolicyDecision
    func rule(for sensitivity: SensitivityLevel) -> PolicyRule?
}

public enum PolicyOperation {
    case openFile
    case shareExternally(recipientDomain: String)
    case shareInternally
    case uploadToCloud
    case exportToLocalFiles
    case screenshot
}

public struct PolicyDecision: Sendable {
    public let allowed: Bool
    public let enforcement: CitedControl.Enforcement
    public let citedControls: [CitedControl]
    public let requiredApprovalRole: String?
    public let auditRequired: Bool

    public init(allowed: Bool, enforcement: CitedControl.Enforcement, citedControls: [CitedControl],
                requiredApprovalRole: String?, auditRequired: Bool) {
        self.allowed = allowed
        self.enforcement = enforcement
        self.citedControls = citedControls
        self.requiredApprovalRole = requiredApprovalRole
        self.auditRequired = auditRequired
    }
}
