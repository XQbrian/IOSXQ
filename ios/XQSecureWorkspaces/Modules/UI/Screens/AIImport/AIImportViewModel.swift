import Foundation

@MainActor
final class AIImportViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scanComplete = false
    @Published var scanSteps: [String] = []
    @Published var result: AIClassificationResult? = nil

    private let aiOrchestrator: any AIOrchestrator
    private let policyEngine: any PolicyEngine

    init(aiOrchestrator: any AIOrchestrator, policyEngine: any PolicyEngine) {
        self.aiOrchestrator = aiOrchestrator
        self.policyEngine = policyEngine
    }

    func startScan() {
        guard !isScanning else { return }
        Task {
            await runScan()
        }
    }

    private func runScan() async {
        isScanning = true
        scanComplete = false
        scanSteps = []
        result = nil

        let steps: [String] = [
            "Initializing CoreML pipeline…",
            "Loading NER model v3.1…",
            "Extracting document text…",
            "Scanning for PHI entities…",
            "Scanning for PII entities…",
            "Scanning for financial data…",
            "Applying policy rules…",
            "Computing risk score…",
            "Finalizing classification…"
        ]

        for step in steps {
            try? await Task.sleep(nanoseconds: 700_000_000)
            scanSteps.append(step)
        }

        // Produce stub result
        let stubFileId = UUID()
        result = AIClassificationResult(
            fileId: stubFileId,
            sensitivity: .restricted,
            riskScore: 87,
            entities: [
                AIEntity(
                    id: UUID(),
                    type: .phi,
                    value: "Patient SSN",
                    confidence: 0.98,
                    citedControl: CitedControl(
                        framework: .hipaa,
                        controlId: "164.514(a)",
                        title: "De-identification of PHI",
                        description: "Protected health information must be de-identified before external disclosure.",
                        enforcement: .block
                    )
                ),
                AIEntity(
                    id: UUID(),
                    type: .financial,
                    value: "Revenue Figures",
                    confidence: 0.91,
                    citedControl: nil
                )
            ],
            modelVersion: "CoreML-3.1",
            processingMs: 2_340,
            wasCloudProcessed: false
        )

        isScanning = false
        scanComplete = true
    }
}
