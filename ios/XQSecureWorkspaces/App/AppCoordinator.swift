import SwiftUI
import XQCore
import XQSecurity
import XQNetworking
import XQRepository
import XQPolicy
import LocalAuthentication

@MainActor
final class AppCoordinator: ObservableObject {

    /// Top-level routes that replace the entire root view. Everything inside
    /// the authenticated app (Files / FileViewer / Messages / Settings /
    /// AdminPolicy / AIImport / etc.) navigates via per-tab NavigationStacks
    /// pushed from MainTabView — *not* via this enum. Adding child screens
    /// here invites dead-end traps (the entire root gets replaced and the
    /// tab bar disappears), so this enum is deliberately small.
    enum AppRoute {
        case splash
        case welcome
        case xqVerification(email: String, idToken: String, msalAccountIdentifier: String, graphToken: String)
        case home
        case securityFailure(JailbreakAssessment)
        case onboarding
    }

    enum AppTab: String, Hashable {
        case files, messages, alerts, ai, settings
    }

    @Published var route: AppRoute = .splash
    @Published var selectedTab: AppTab = .files
    @Published var currentSession: XQSession? = nil
    @Published var graphToken: String? = nil

    /// Presents the Profile sheet over MainTabView. Triggered from the
    /// top-right avatar on each top-level screen (mirrors the prototype's
    /// universal Profile entry point).
    @Published var showingProfile: Bool = false
    func presentProfile() { showingProfile = true }
    func dismissProfile() { showingProfile = false }

    /// Active file repository — nil until authentication completes.
    var repository: (any RepositoryProvider)?
    /// Local encrypted vault — created on first authentication.
    private(set) var localVaultProvider: LocalVaultProvider?
    /// On-device XQ API for AES-256-GCM + Keychain DEK storage.
    private(set) var xqAPI: (any XQSecureAPI)?
    /// Policy engine shared across all screens.
    let policyEngine = FuzzyPolicyEngine()

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

        let api: any XQSecureAPI = makeXQAPI(session: session)
        xqAPI = api
        let store = SecureFileStore(enclaveManager: NullEnclaveManager())
        let vault = LocalVaultProvider(fileStore: store, xqAPI: api)
        localVaultProvider = vault

        Task {
            try? await policyEngine.loadBundle(defaultPolicyBundle())
            await vault.setSession(session)
        }

        selectedTab = .files
        let hasOnboarded = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        route = hasOnboarded ? .home : .onboarding
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        route = .home
    }

    func startFree() {
        let storedId = UserDefaults.standard.string(forKey: "xq.freeUserId") ?? {
            let id = "local-\(UUID().uuidString.prefix(8).lowercased())"
            UserDefaults.standard.set(id, forKey: "xq.freeUserId")
            return id
        }()
        let session = XQSession(
            userId: storedId,
            tenantId: "free-local",
            accessToken: "dev-token",
            expiresAt: Date().addingTimeInterval(365 * 24 * 3600),
            apiVersion: .v3
        )
        currentSession = session
        graphToken = nil
        repository = nil

        let api: any XQSecureAPI = LocalOnlySecureAPI()
        xqAPI = api
        let store = SecureFileStore(enclaveManager: NullEnclaveManager())
        let vault = LocalVaultProvider(fileStore: store, xqAPI: api)
        localVaultProvider = vault

        Task {
            try? await policyEngine.loadBundle(defaultPolicyBundle())
            await vault.setSession(session)
        }

        selectedTab = .files
        let hasOnboarded = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        route = hasOnboarded ? .home : .onboarding
    }

    #if targetEnvironment(simulator)
    func devLogin() {
        let session = XQSession(
            userId: "brian@xqmsg.com",
            tenantId: "dev-tenant",
            accessToken: "dev-token",
            expiresAt: Date().addingTimeInterval(3600 * 8),
            apiVersion: .v3
        )
        completeAuthentication(session: session, graphToken: "dev-graph-token")
    }
    #endif

    func signOut() {
        Task {
            await authOrchestrator.signOut()
            currentSession = nil
            graphToken = nil
            repository = nil
            localVaultProvider = nil
            xqAPI = nil
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
            if currentSession != nil && biometricLockEnabled {
                let ok = await evaluateBiometric()
                if !ok {
                    route = .welcome
                    return
                }
            }
            if currentSession == nil || sessionIsStale() { route = .welcome }
        }
    }

    private var biometricLockEnabled: Bool {
        UserDefaults.standard.object(forKey: "xq.biometricLock") as? Bool ?? true
    }

    private func evaluateBiometric() async -> Bool {
        let context = LAContext()
        var nsError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &nsError
        ) else { return true }
        return (try? await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock XQ Secure Workspace"
        )) ?? false
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

    private func defaultPolicyBundle() -> PolicyBundle {
        PolicyBundle(
            version: "1.0",
            signatureHex: String(repeating: "a", count: 64),
            rules: SensitivityLevel.allCases.map { level in
                PolicyRule(
                    id: UUID(),
                    name: "\(level.rawValue) Policy",
                    sensitivity: level,
                    allowExternalShare: level == .public_ || level == .internal_,
                    maxShareExpiryDays: level == .restricted ? nil : 30,
                    requireApprovalFromRole: level == .restricted ? "admin" : nil,
                    cloudAIPermitted: level == .public_
                )
            },
            fetchedAt: Date()
        )
    }
}

// MARK: - Private helpers used only during auth setup

extension AppCoordinator {
    /// Returns XQAPIV3Adapter for real sessions (DEK registered with XQ KMS) and
    /// LocalOnlySecureAPI for dev/simulator sessions (DEK stored in Keychain only).
    fileprivate func makeXQAPI(session: XQSession) -> any XQSecureAPI {
        guard session.accessToken != "dev-token" else { return LocalOnlySecureAPI() }
        let info = Bundle.main.infoDictionary ?? [:]
        var baseStr = info["XQ_BASE_URL"] as? String ?? "https://subscription.xqmsg.net/v2"
        // Strip the version path so the gateway owns path construction.
        if let range = baseStr.range(of: "/v", options: .backwards) {
            baseStr = String(baseStr[..<range.lowerBound])
        }
        let gateway = XQAPIGateway(
            baseURL: URL(string: baseStr)!,
            pinner: NullCertPinner()
        )
        return XQAPIV3Adapter(gateway: gateway)
    }
}

private struct NullEnclaveManager: SecureEnclaveManager, @unchecked Sendable {
    var isAvailable: Bool { false }
    func generateRootKey() async throws -> SecureEnclaveKeyReference { .init(tag: "") }
    func deriveKeyEncryptionKey(from root: SecureEnclaveKeyReference) async throws -> Data { Data() }
    func sign(data: Data, with key: SecureEnclaveKeyReference) async throws -> Data { Data() }
    func verify(signature: Data, for data: Data, with key: SecureEnclaveKeyReference) async throws -> Bool { false }
    func deleteKey(_ reference: SecureEnclaveKeyReference) async throws {}
}

private struct NullCertPinner: CertificatePinner, @unchecked Sendable {
    func validate(serverTrust: SecTrust, hostname: String) throws {}
    func updatePins(_ pins: [String: [String]]) async {}
}
