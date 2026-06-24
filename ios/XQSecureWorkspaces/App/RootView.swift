import SwiftUI
import XQCore
import XQSecurity

struct RootView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        switch coordinator.route {
        case .splash:
            SplashView()
        case .welcome:
            WelcomeView()
        case .xqVerification(let email, let idToken, let msalAccountIdentifier, let graphToken):
            XQVerificationView(
                email: email,
                idToken: idToken,
                msalAccountIdentifier: msalAccountIdentifier,
                graphToken: graphToken
            )
        case .home:
            MainTabView()
        case .onboarding:
            OnboardingView()
        case .securityFailure(let assessment):
            SecurityFailureView(assessment: assessment)
        }
        // Note: there are intentionally NO root-replacement cases for Files,
        // FileViewer, Messages, Settings, AdminPolicy, or AIImport. Those all
        // live inside MainTabView's per-tab NavigationStacks (push) or as
        // sheets — that's what gives every screen a back path.
    }
}

// MARK: - Security Failure

private struct SecurityFailureView: View {
    let assessment: JailbreakAssessment

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            Text("Security Check Failed")
                .font(.title2.bold())
            Text("This device cannot be trusted. Access is denied.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("Jailbreak confidence: \(assessment.confidenceScore)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
