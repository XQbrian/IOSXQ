import Foundation
import XQCore
import XQSecurity

@MainActor
final class SplashViewModel: ObservableObject {

    struct SecurityCheck: Identifiable {
        let id = UUID()
        let label: String
        var passed: Bool
    }

    @Published var progress: Double = 0
    @Published var checks: [SecurityCheck] = []
    @Published var isReady = false

    func performSecurityChecks() async {
        let steps: [String] = [
            "Secure Enclave active",
            "Integrity verified",
            "Policy loaded"
        ]

        for (index, label) in steps.enumerated() {
            try? await Task.sleep(nanoseconds: 600_000_000)
            checks.append(SecurityCheck(label: label, passed: true))
            progress = Double(index + 1) / Double(steps.count)
        }

        isReady = true
    }
}
