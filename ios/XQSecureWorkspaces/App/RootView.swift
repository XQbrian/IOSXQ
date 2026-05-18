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
            EnterpriseLoginView()
        case .xqVerification(let email, let idToken, let msalAccountIdentifier):
            XQVerificationView(
                email: email,
                idToken: idToken,
                msalAccountIdentifier: msalAccountIdentifier
            )
        case .home:
            FileBrowserView()
        case .fileBrowser:
            FileBrowserView()
        case .fileViewer(let file):
            NavigationStack {
                FileViewerView(file: file)
            }
        case .aiImport:
            Text("AI Import — Coming Soon")
        case .emailInbox:
            Text("Email Inbox — Coming Soon")
        case .settings:
            SettingsRootView()
        case .adminPolicy:
            Text("Admin Policy — Coming Soon")
        case .securityFailure(let assessment):
            SecurityFailureView(assessment: assessment)
        }
    }
}

// MARK: - Settings (sign-out entry point)

private struct SettingsRootView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(role: .destructive) {
                        coordinator.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                }
            }
            .navigationTitle("Settings")
        }
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
