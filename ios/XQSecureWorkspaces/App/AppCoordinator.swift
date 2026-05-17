import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {

    enum AppRoute {
        case splash
        case welcome
        case home
        case fileBrowser
        case fileViewer(SecureFile)
        case aiImport
        case emailInbox
        case settings
        case adminPolicy
        case securityFailure(JailbreakAssessment)
    }

    @Published var route: AppRoute = .splash

    private let sessionManager: any SessionManager
    private let jailbreakDetector: any JailbreakDetector

    init(
        sessionManager: any SessionManager = DefaultSessionManager(),
        jailbreakDetector: any JailbreakDetector = JailbreakDetectorImpl()
    ) {
        self.sessionManager = sessionManager
        self.jailbreakDetector = jailbreakDetector
        Task { await runStartupChecks() }
    }

    func navigate(to route: AppRoute) {
        self.route = route
    }

    func handleForeground() {
        Task {
            let assessment = await jailbreakDetector.assess()
            if assessment.confidenceScore > 40 {
                route = .securityFailure(assessment)
                return
            }
            if sessionManager.requiresReauthentication() {
                route = .welcome
            }
        }
    }

    private func runStartupChecks() async {
        let assessment = await jailbreakDetector.assess()
        guard assessment.confidenceScore <= 40 else {
            route = .securityFailure(assessment)
            return
        }
    }
}

// Placeholder conformances allow the coordinator to compile before real
// implementations are wired through DI at the composition root.
private final class DefaultSessionManager: SessionManager {
    var currentSession: XQSession? { nil }
    func startSession(credentials: XQCredentials) async throws -> XQSession {
        throw XQAPIError.unauthenticated
    }
    func endSession() async {}
    func requiresReauthentication() -> Bool { true }
}
