import SwiftUI

struct RootView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        switch coordinator.route {
        case .splash:
            SplashView()
        case .welcome:
            Text("Welcome")
        case .home:
            Text("Home")
        case .fileBrowser:
            Text("File Browser")
        case .fileViewer(let file):
            Text("File Viewer: \(file.name)")
        case .aiImport:
            Text("AI Import")
        case .emailInbox:
            Text("Email Inbox")
        case .settings:
            Text("Settings")
        case .adminPolicy:
            Text("Admin Policy")
        case .securityFailure(let assessment):
            Text("Security check failed (score: \(assessment.confidenceScore))")
        }
    }
}
