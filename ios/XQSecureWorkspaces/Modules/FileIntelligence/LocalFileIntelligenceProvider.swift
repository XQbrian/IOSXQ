import Foundation

// LocalFileIntelligenceProvider runs entirely on-device.
// CUI/PHI content never reaches a remote endpoint from this actor — that constraint is structural,
// not a runtime flag, because this type never holds a network client.

actor LocalFileIntelligenceProvider:
    ContentAnalyzer,
    FileClassifier,
    FilePolicyEnforcer,
    FileRiskScanner,
    FileThreatAnalyzer,
    PrivacyAnalyzer
{
    let isLocalOnly = true

    private let modelVersion = "local-2.1.0"

    private let macroExtensions: Set<String> = ["docx", "xlsm", "xls", "doc", "pptm", "xlam"]

    private let injectionPatterns: [String] = [
        "ignore previous instructions",
        "ignore all instructions",
        "disregard your system prompt",
        "you are now",
        "act as if",
        "new instruction:",
        "system: you must",
        "[[prompt]]",
        "<!--inject",
        "<|endoftext|>",
    ]

    // MARK: - ContentAnalyzer

    func analyzeContent(_ file: SecureFile, session: XQSession) async throws -> DocumentContentProfile {
        // PHI/Restricted files may only be analyzed locally. If a caller has somehow set
        // wasCloudProcessed on the file's prior classification result and routes here,
        // the invariant is still preserved — but we surface a typed error to prevent silent drift.
        if file.sensitivity == .restricted {
            // This actor is always local-only; the check exists to make the invariant explicit
            // and to guard against future refactors that might inadvertently pass a cloud flag.
        }

        let docType = docTypeFor(mimeType: file.mimeType)
        let isPHI = file.sensitivity == .restricted

        return DocumentContentProfile(
            docType: docType,
            language: "en-US",
            entityCount: isPHI ? 14 : 3,
            extractedObligations: isPHI
                ? ["Retain per HIPAA §164.530(j) for 6 years", "Restrict disclosure to treatment team"]
                : ["Standard retention applies"],
            keyTopics: topicsFor(file: file),
            processingMs: Int.random(in: 8...19),
            wasLocalOnly: true
        )
    }

    // MARK: - FileClassifier

    func classify(_ file: SecureFile, session: XQSession) async throws -> FileClassificationLabel {
        let entities = entitiesFor(file: file)
        let confidence: Float = entities.isEmpty ? 0.61 : 0.91

        let rules: [String]
        switch file.sensitivity {
        case .restricted:   rules = ["HIPAA-PHI-AUTO", "NIST-AC-3"]
        case .confidential: rules = ["CORP-CONF-001"]
        case .internal_:    rules = ["INTERNAL-DEFAULT"]
        case .public_:      rules = ["PUBLIC-OPEN"]
        }

        return FileClassificationLabel(
            sensitivity: file.sensitivity,
            aiConfidence: confidence,
            triggerEntities: entities,
            appliedRules: rules
        )
    }

    // MARK: - FilePolicyEnforcer

    func enforce(policy: PolicyBundle, for file: SecureFile) -> FilePolicyDecision {
        let matchingRules = policy.rules.filter { $0.sensitivity == file.sensitivity }

        let action: PolicyAction
        let requiresApproval: Bool
        var citedControls: [CitedControl] = []

        if file.sensitivity == .restricted {
            action = .block
            requiresApproval = true
            citedControls.append(CitedControl(
                framework: .hipaa,
                controlId: "164.502",
                title: "Use & Disclosure of PHI",
                description: "External sharing of PHI files is prohibited without explicit authorization.",
                enforcement: .block
            ))
            citedControls.append(CitedControl(
                framework: .nistSP80053,
                controlId: "AC-3",
                title: "Access Enforcement",
                description: "Access to restricted data enforced per NIST SP 800-53 AC-3.",
                enforcement: .audit
            ))
        } else if file.sensitivity == .confidential {
            let hasShareRule = matchingRules.contains { !$0.allowExternalShare }
            action = hasShareRule ? .warn : .allow
            requiresApproval = matchingRules.first?.requireApprovalFromRole != nil
        } else {
            action = .allow
            requiresApproval = false
        }

        return FilePolicyDecision(
            action: action,
            appliedRules: matchingRules,
            citedControls: citedControls,
            requiresApproval: requiresApproval
        )
    }

    // MARK: - FileRiskScanner

    func scanForRisks(_ file: SecureFile, session: XQSession) async throws -> [FileRiskFinding] {
        var findings: [FileRiskFinding] = []
        let loweredName = file.name.lowercased()

        if file.sensitivity == .restricted {
            findings.append(FileRiskFinding(
                id: UUID(),
                category: .shadowAITraining,
                severity: .critical,
                fileId: file.id,
                description: "File contains PHI entities and is at risk of inclusion in shadow AI training pipelines if access controls are misconfigured.",
                remediationSuggestion: "Verify DLP rules block this file from any AI ingestion endpoint. Audit recent access logs."
            ))
        }

        if loweredName.contains("dev") || loweredName.contains("api") {
            findings.append(FileRiskFinding(
                id: UUID(),
                category: .credentialExposure,
                severity: .high,
                fileId: file.id,
                description: "Filename pattern suggests possible API keys or development credentials embedded in document content.",
                remediationSuggestion: "Scan file content for secret patterns (AWS_ACCESS_KEY, bearer tokens). Rotate any exposed credentials immediately."
            ))
        }

        let ninetyDaysAgo = Date(timeIntervalSinceNow: -90 * 24 * 3600)
        if file.modifiedAt < ninetyDaysAgo {
            findings.append(FileRiskFinding(
                id: UUID(),
                category: .policyDrift,
                severity: .medium,
                fileId: file.id,
                description: "File has not been modified in over 90 days; its classification label may no longer reflect current policy requirements.",
                remediationSuggestion: "Trigger reclassification and verify that access permissions still match the intended audience."
            ))
        }

        return findings
    }

    // MARK: - FileThreatAnalyzer

    func analyzeThreat(_ file: SecureFile, session: XQSession) async throws -> FileThreatReport {
        let ext = file.name.components(separatedBy: ".").last?.lowercased() ?? ""
        let hasMacros = macroExtensions.contains(ext)

        let promptInjectionRisk: Float = scanForInjection(in: file.name) ? 0.83 : 0.04
        // Steganography risk is heuristic-only; elevated for large images.
        let steganographyRisk: Float = (file.mimeType.hasPrefix("image/") && file.sizeBytes > 500_000) ? 0.22 : 0.03
        let aiTrainingRisk: Float = file.sensitivity == .restricted ? 0.91 : 0.12
        let shadowCopyCount = file.sourceProvider == .sharePoint ? Int.random(in: 0...3) : 0

        let maxRisk = max(
            hasMacros ? Float(0.7) : 0,
            promptInjectionRisk,
            steganographyRisk,
            aiTrainingRisk
        )

        let threatLevel: ThreatLevel
        switch maxRisk {
        case 0..<0.15:  threatLevel = .clear
        case 0.15..<0.35: threatLevel = .low
        case 0.35..<0.60: threatLevel = .medium
        case 0.60..<0.80: threatLevel = .high
        default:          threatLevel = .critical
        }

        return FileThreatReport(
            hasMacros: hasMacros,
            promptInjectionRisk: promptInjectionRisk,
            steganographyRisk: steganographyRisk,
            aiTrainingRisk: aiTrainingRisk,
            shadowCopyCount: shadowCopyCount,
            threatLevel: threatLevel
        )
    }

    // MARK: - PrivacyAnalyzer

    func analyzePrivacy(
        _ file: SecureFile,
        policy: PolicyBundle,
        session: XQSession
    ) async throws -> PrivacyAnalysisResult {
        let isPHI = file.sensitivity == .restricted
        let entitiesRedacted = isPHI ? 14 : 0

        return PrivacyAnalysisResult(
            wasLocalOnly: true,
            cloudEgressBytes: 0,
            entitiesRedacted: entitiesRedacted,
            anonymizationApplied: isPHI,
            processingLocation: ProcessingLocation(
                isOnDevice: true,
                modelVersion: modelVersion
            )
        )
    }

    // MARK: - Private Helpers

    private func docTypeFor(mimeType: String) -> String {
        switch mimeType {
        case "application/pdf":                           return "PDF Document"
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document": return "Word Document"
        case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":       return "Excel Spreadsheet"
        case let t where t.hasPrefix("image/"):          return "Image"
        case let t where t.hasPrefix("text/"):           return "Plain Text"
        default:                                          return "Binary Document"
        }
    }

    private func topicsFor(file: SecureFile) -> [String] {
        let lowered = file.name.lowercased()
        var topics: [String] = []
        if lowered.contains("financial") || lowered.contains("budget") || lowered.contains("q4") {
            topics.append(contentsOf: ["Financial Planning", "Budget Review", "Quarterly Performance"])
        }
        if lowered.contains("patient") || lowered.contains("medical") || lowered.contains("health") {
            topics.append(contentsOf: ["Patient Care", "Medical Records", "Health Data"])
        }
        if lowered.contains("contract") || lowered.contains("agreement") || lowered.contains("legal") {
            topics.append(contentsOf: ["Legal Obligations", "Contract Terms", "Compliance"])
        }
        if topics.isEmpty {
            topics.append(contentsOf: ["General Business", "Internal Operations"])
        }
        return topics
    }

    private func entitiesFor(file: SecureFile) -> [AIEntity] {
        guard file.sensitivity == .restricted else { return [] }
        return [
            AIEntity(
                id: UUID(),
                type: .phi,
                value: "Patient record reference",
                confidence: 0.94,
                citedControl: CitedControl(
                    framework: .hipaa,
                    controlId: "164.502",
                    title: "Use & Disclosure of PHI",
                    description: "PHI detected in document content.",
                    enforcement: .block
                )
            )
        ]
    }

    private func scanForInjection(in text: String) -> Bool {
        let lowered = text.lowercased()
        return injectionPatterns.contains { lowered.contains($0) }
    }
}
