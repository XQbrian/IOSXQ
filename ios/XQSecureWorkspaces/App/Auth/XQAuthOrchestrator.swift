import Foundation
import UIKit
import XQCore

// Orchestrates the full authentication flow:
// MSAL (Azure AD SSO) → XQ OTP verification → XQSession in memory
// Session restore on app restart: silent MSAL re-auth check + Keychain metadata.
actor XQAuthOrchestrator {

    private let msalProvider: MSALAuthProvider
    private let xqClient: XQSubscriptionClient
    private let attestService: AppAttestService
    private let keychainStore: KeychainSessionStore

    // In-memory only — accessToken NEVER written to disk.
    private var _session: XQSession?
    var currentSession: XQSession? { _session }

    init(
        msalProvider: MSALAuthProvider,
        xqClient: XQSubscriptionClient,
        attestService: AppAttestService,
        keychainStore: KeychainSessionStore
    ) {
        self.msalProvider = msalProvider
        self.xqClient = xqClient
        self.attestService = attestService
        self.keychainStore = keychainStore
    }

    // MARK: - Step 1: Enterprise SSO

    // msalProvider is @MainActor so this method hops to main thread for the MSAL call.
    @MainActor
    func initiateEnterpriseLogin(from viewController: UIViewController) async throws -> MSALAuthResult {
        try await msalProvider.acquireToken(from: viewController)
    }

    // Likewise for silent re-auth.
    @MainActor
    func acquireTokenSilentIfPossible(accountIdentifier: String) async throws -> MSALAuthResult {
        try await msalProvider.acquireTokenSilent(accountIdentifier: accountIdentifier)
    }

    // MARK: - Step 2: XQ OTP

    func sendXQVerificationCode(email: String) async throws {
        try await xqClient.authorize(email: email)
    }

    // MARK: - Step 3: Complete auth

    // Validates pin, fetches subscriber profile, builds XQSession in memory,
    // persists non-sensitive metadata to Keychain (no accessToken stored).
    func verifyAndCreateSession(
        email: String,
        pin: String,
        msalAccountIdentifier: String
    ) async throws -> XQSession {
        let token = try await xqClient.validatePin(pin)
        let profile = try await xqClient.fetchSubscriber(token: token)
        let assertion = try await attestService.createAssertion(for: Data(token.utf8))

        let session = XQSession(
            userId: profile.id,
            tenantId: email.components(separatedBy: "@").last ?? email,
            accessToken: token,
            expiresAt: Date().addingTimeInterval(3600 * 8),
            apiVersion: .v2
        )
        _session = session
        try await keychainStore.save(session: session, msalAccountIdentifier: msalAccountIdentifier)
        _ = assertion
        return session
    }

    // MARK: - Session restore

    // Called on splash. Returns nil if interactive login is required.
    // Silent MSAL token refresh confirms the AAD account still exists; the XQ
    // OTP flow cannot be silently replayed, so we still return nil (user must
    // sign in again). In a future enterprise federation build, replace with a
    // silent XQ token exchange using the refreshed AAD token.
    @MainActor
    func restoreSessionIfPossible() async -> XQSession? {
        guard await keychainStore.hasUnexpiredMetadata(),
              let metadata = try? await keychainStore.load() else { return nil }
        // Confirm AAD account is still cached; ignore result — can't restore XQ token silently.
        _ = try? await msalProvider.acquireTokenSilent(accountIdentifier: metadata.msalAccountIdentifier)
        return nil
    }

    // MARK: - Sign out

    func signOut() async {
        if let session = _session {
            _ = try? await xqClient.revokeToken(session.accessToken)
        }
        _session = nil
        await keychainStore.clear()
        // msalProvider is @MainActor; hop to main thread for sign-out.
        await MainActor.run { try? msalProvider.signOut() }
    }
}
