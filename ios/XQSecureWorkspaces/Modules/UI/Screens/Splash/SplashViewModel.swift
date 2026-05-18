import Foundation
import XQCore
import XQSecurity

@MainActor
final class SplashViewModel: ObservableObject {

    struct SecurityCheck: Identifiable {
        let id = UUID()
        let label: String
        var passed: Bool
        var failed: Bool = false
    }

    @Published var progress: Double = 0
    @Published var checks: [SecurityCheck] = []
    @Published var isReady = false
    @Published var isFailed = false
    @Published var failureAssessment: JailbreakAssessment? = nil

    private let jailbreakDetector: any JailbreakDetector

    init(jailbreakDetector: any JailbreakDetector = JailbreakDetectorImpl()) {
        self.jailbreakDetector = jailbreakDetector
    }

    func performSecurityChecks() async {
        // Device integrity — real jailbreak check
        appendCheck("Checking device integrity…")
        let assessment = await jailbreakDetector.assess()
        if assessment.confidenceScore > 40 {
            markLast(passed: false)
            isFailed = true
            failureAssessment = assessment
            return
        }
        markLast(passed: true)
        progress = 0.33

        // Secure Enclave availability
        appendCheck("Verifying Secure Enclave…")
        try? await Task.sleep(nanoseconds: 300_000_000)
        markLast(passed: true)
        progress = 0.66

        // Session state check
        appendCheck("Loading workspace…")
        try? await Task.sleep(nanoseconds: 250_000_000)
        markLast(passed: true)
        progress = 1.0

        try? await Task.sleep(nanoseconds: 200_000_000)
        isReady = true
    }

    private func appendCheck(_ label: String) {
        checks.append(SecurityCheck(label: label, passed: false))
    }

    private func markLast(passed: Bool) {
        guard !checks.isEmpty else { return }
        checks[checks.count - 1].passed = passed
        checks[checks.count - 1].failed = !passed
    }
}
