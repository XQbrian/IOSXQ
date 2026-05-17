import Foundation

@MainActor
final class FileViewerViewModel: ObservableObject {

    @Published var file: SecureFile
    @Published var classificationResult: AIClassificationResult? = nil
    @Published var citedControls: [CitedControl] = []
    @Published var policyDecision: PolicyDecision? = nil
    @Published var isScanning = false
    @Published var decryptedPreviewData: Data? = nil

    private let aiOrchestrator: any AIOrchestrator
    private let policyEngine: any PolicyEngine
    private let xqAPI: any XQSecureAPI

    init(
        file: SecureFile,
        aiOrchestrator: any AIOrchestrator,
        policyEngine: any PolicyEngine,
        xqAPI: any XQSecureAPI
    ) {
        self.file = file
        self.aiOrchestrator = aiOrchestrator
        self.policyEngine = policyEngine
        self.xqAPI = xqAPI
    }

    func loadAndScan(session: XQSession) async {
        isScanning = true
        defer { isScanning = false }

        guard let bundle = policyEngine.currentBundle else { return }

        do {
            let encryptedPayload = EncryptedPayload(
                ciphertext: Data(),
                iv: Data(),
                authTag: Data(),
                keyId: file.encryptedKeyId
            )
            let plainData = try await xqAPI.decryptFile(encryptedPayload, session: session)
            decryptedPreviewData = plainData

            let result = try await aiOrchestrator.scanAndClassify(
                fileData: plainData,
                mimeType: file.mimeType,
                policy: bundle
            )
            classificationResult = result
            citedControls = result.entities.compactMap { $0.citedControl }

            let openDecision = await policyEngine.evaluate(
                operation: .openFile,
                for: file,
                actor: session.userId
            )
            let shareDecision = await policyEngine.evaluate(
                operation: .shareExternally(recipientDomain: ""),
                for: file,
                actor: session.userId
            )

            // Share decision is the more restrictive context the viewer exposes
            policyDecision = shareDecision
            let additionalControls = openDecision.citedControls + shareDecision.citedControls
            let existingIds = Set(citedControls.map { $0.controlId })
            citedControls += additionalControls.filter { !existingIds.contains($0.controlId) }
        } catch {
            // Errors surface through the absence of classificationResult / decryptedPreviewData
        }
    }

    func requestShareApproval() async throws {
        guard let decision = policyDecision else {
            throw XQAPIError.policyViolation(rule: "No policy decision available")
        }
        guard decision.allowed else {
            throw XQAPIError.policyViolation(
                rule: decision.citedControls.first?.controlId ?? "POLICY_BLOCK"
            )
        }
    }
}
