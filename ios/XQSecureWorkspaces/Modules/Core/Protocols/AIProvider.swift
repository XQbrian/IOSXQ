import Foundation

protocol AIProvider: Sendable {
    var isLocalOnly: Bool { get }

    func classify(fileData: Data, mimeType: String, policy: PolicyBundle) async throws -> AIClassificationResult
    func extractEntities(from text: String, policy: PolicyBundle) async throws -> [AIEntity]
    func scoreRisk(file: SecureFile, entities: [AIEntity], policy: PolicyBundle) async throws -> Int
}

// Cloud AI is only permitted when BOTH conditions are true:
// 1. The enterprise policy bundle has cloudAIPermitted == true for this sensitivity level
// 2. The file's SensitivityLevel is NOT .restricted (PHI/CUI is always local-only)
enum AIProviderGateError: Error {
    case cloudAIDisabledByPolicy
    case cloudAIForbiddenForSensitivityLevel(SensitivityLevel)
    case modelNotLoaded(modelName: String)
    case classificationFailed(underlying: Error)
}

// CUI/PHI → CoreMLProvider unconditionally; no override possible.
protocol AIOrchestrator: Sendable {
    func provider(for sensitivity: SensitivityLevel, policy: PolicyBundle) -> any AIProvider
    func scanAndClassify(fileData: Data, mimeType: String, policy: PolicyBundle) async throws -> AIClassificationResult
}
