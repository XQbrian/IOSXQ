import Foundation

actor CoreMLProvider: AIProvider {

    let isLocalOnly = true

    private let sensitiveEntityClassifierName = "SensitiveEntityClassifier"
    private let documentClassifierName = "DocumentClassifier"
    private let riskScorerName = "RiskScoringModel"

    func classify(
        fileData: Data,
        mimeType: String,
        policy: PolicyBundle
    ) async throws -> AIClassificationResult {
        guard Bundle.main.url(forResource: documentClassifierName, withExtension: "mlmodelc") != nil else {
            throw AIProviderGateError.modelNotLoaded(modelName: documentClassifierName)
        }

        // Stub preserves the protocol boundary until the real MLModel pipeline is wired in.
        return AIClassificationResult(
            fileId: UUID(),
            sensitivity: .confidential,
            riskScore: 67,
            entities: [],
            modelVersion: "1.0.0",
            processingMs: 1400,
            wasCloudProcessed: false
        )
    }

    func extractEntities(from text: String, policy: PolicyBundle) async throws -> [AIEntity] {
        return []
    }

    func scoreRisk(file: SecureFile, entities: [AIEntity], policy: PolicyBundle) async throws -> Int {
        return min(entities.count * 8, 100)
    }
}
