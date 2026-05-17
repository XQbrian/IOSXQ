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
            Text("Welcome — Coming Soon")
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
            Text("Settings — Coming Soon")
        case .adminPolicy:
            Text("Admin Policy — Coming Soon")
        case .securityFailure(let assessment):
            SecurityFailureView(assessment: assessment)
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
            Text("Jailbreak confidence: \(assessment.confidenceScore)%")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
