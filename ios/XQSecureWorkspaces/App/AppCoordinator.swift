import SwiftUI
import XQCore
import XQSecurity
import XQNetworking
import XQPolicy

@MainActor
final class AppCoordinator: ObservableObject {

    enum AppRoute {
        case splash
        case welcome
        case xqVerification(email: String, idToken: String, msalAccountIdentifier: String, graphToken: String)
        case home
        case fileBrowser
        case fileViewer(SecureFile)
        case aiImport
        case emailInbox
        case settings
        case adminPolicy
        case securityFailure(JailbreakAssessment)
        case onboarding
    }

    enum AppTab: String, Hashable {
        case home, files, email, sharing, settings
    }

    @Published var route: AppRoute = .splash
    @Published var selectedTab: AppTab = .home
    @Published var currentSession: XQSession? = nil
    @Published var graphToken: String? = nil

    /// Active file repository — nil until authentication completes.
    /// Both FileBrowserViewModel and FileViewerViewModel read from here.
    var repository: (any RepositoryProvider)?

    let authOrchestrator: XQAuthOrchestrator
    private let jailbreakDetector: any JailbreakDetector

    init(
        authOrchestrator: XQAuthOrchestrator? = nil,
        jailbreakDetector: any JailbreakDetector = JailbreakDetectorImpl()
    ) {
        self.jailbreakDetector = jailbreakDetector

        if let provided = authOrchestrator {
            self.authOrchestrator = provided
        } else {
            let info = Bundle.main.infoDictionary ?? [:]
            let apiKey   = info["XQ_API_KEY"]  as? String ?? ""
            let baseURL  = URL(string: info["XQ_BASE_URL"] as? String ?? "https://subscription.xqmsg.net/v2")!
            let clientId = info["AZURE_CLIENT_ID"] as? String ?? ""
            let tenantId = info["AZURE_TENANT_ID"] as? String ?? ""
            let bundleId = Bundle.main.bundleIdentifier ?? "com.xqmsg.ios.secureworkspaces"

            let msalProvider = (try? MSALAuthProvider(clientId: clientId, tenantId: tenantId, bundleId: bundleId))
                ?? (try! MSALAuthProvider(clientId: "placeholder", tenantId: "common", bundleId: bundleId))
            self.authOrchestrator = XQAuthOrchestrator(
                msalProvider: msalProvider,
                xqClient: XQSubscriptionClient(apiKey: apiKey, baseURL: baseURL),
                attestService: AppAttestService(),
                keychainStore: KeychainSessionStore()
            )
        }

        Task { await runStartupChecks() }
    }

    private static let onboardingKey = "xq.hasOnboarded"

    func navigate(to route: AppRoute) { self.route = route }

    func completeAuthentication(session: XQSession, graphToken: String) {
        currentSession = session
        self.graphToken = graphToken
        repository = MicrosoftGraphRepository(graphToken: graphToken)
        selectedTab = .home
        let hasOnboarded = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        route = hasOnboarded ? .home : .onboarding
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        route = .home
    }

    func signOut() {
        Task {
            await authOrchestrator.signOut()
            currentSession = nil
            graphToken = nil
            repository = nil
            route = .welcome
        }
    }

    func handleForeground() {
        Task {
            let assessment = await jailbreakDetector.assess()
            if assessment.confidenceScore > 40 {
                route = .securityFailure(assessment)
                return
            }
            if currentSession == nil || sessionIsStale() { route = .welcome }
        }
    }

    private func runStartupChecks() async {
        let assessment = await jailbreakDetector.assess()
        guard assessment.confidenceScore <= 40 else {
            route = .securityFailure(assessment)
            return
        }
        let restored = await authOrchestrator.restoreSessionIfPossible()
        if let session = restored {
            currentSession = session
            route = .home
        } else {
            route = .welcome
        }
    }

    private func sessionIsStale() -> Bool {
        guard let s = currentSession else { return true }
        return s.expiresAt <= Date().addingTimeInterval(300)
    }
}
