import Foundation

private let controlHIPAA164502 = CitedControl(
    framework: .hipaa,
    controlId: "HIPAA-164.502",
    title: "Uses and disclosures of protected health information: general rules",
    description: "Covered entities may not use or disclose PHI except as permitted or required by HIPAA.",
    enforcement: .block
)

private let controlNISTAC3 = CitedControl(
    framework: .nistSP80053,
    controlId: "NIST-AC-3",
    title: "Access Enforcement",
    description: "Enforce approved authorizations for logical access to information and system resources.",
    enforcement: .block
)

private let controlNISTSI12 = CitedControl(
    framework: .nistSP80053,
    controlId: "NIST-SI-12",
    title: "Information Management and Retention",
    description: "Manage and retain information within the system and information output from the system.",
    enforcement: .audit
)

actor FuzzyPolicyEngine: PolicyEngine {

    private(set) var currentBundle: PolicyBundle? = nil

    func loadBundle(_ bundle: PolicyBundle) async throws {
        guard !bundle.signatureHex.isEmpty else {
            throw XQAPIError.policyViolation(rule: "Policy bundle signature is missing")
        }
        currentBundle = bundle
    }

    func evaluate(
        operation: PolicyOperation,
        for file: SecureFile,
        actor actorId: String
    ) async -> PolicyDecision {
        guard let bundle = currentBundle else {
            return .blocked(controls: [controlNISTAC3])
        }

        guard let rule = bundle.rules.first(where: { $0.sensitivity == file.sensitivity }) else {
            return .blocked(controls: [controlNISTAC3])
        }

        switch operation {
        case .shareExternally:
            if !rule.allowExternalShare {
                var controls: [CitedControl] = [controlNISTAC3]
                if file.sensitivity == .restricted {
                    controls.append(controlHIPAA164502)
                }
                return .blocked(controls: controls, approvalRole: rule.requireApprovalFromRole)
            }

            var controls: [CitedControl] = [controlNISTSI12]
            if file.sensitivity == .restricted {
                controls.append(controlHIPAA164502)
            }
            return PolicyDecision(
                allowed: true,
                enforcement: .audit,
                citedControls: controls,
                requiredApprovalRole: rule.requireApprovalFromRole,
                auditRequired: true
            )

        case .openFile, .shareInternally, .uploadToCloud, .exportToLocalFiles, .screenshot:
            return .allowed(controls: [controlNISTSI12])
        }
    }

    func rule(for sensitivity: SensitivityLevel) -> PolicyRule? {
        currentBundle?.rules.first { $0.sensitivity == sensitivity }
    }
}

private extension PolicyDecision {
    static func blocked(controls: [CitedControl], approvalRole: String? = nil) -> PolicyDecision {
        PolicyDecision(allowed: false, enforcement: .block, citedControls: controls, requiredApprovalRole: approvalRole, auditRequired: true)
    }
    static func allowed(controls: [CitedControl]) -> PolicyDecision {
        PolicyDecision(allowed: true, enforcement: .audit, citedControls: controls, requiredApprovalRole: nil, auditRequired: true)
    }
}
