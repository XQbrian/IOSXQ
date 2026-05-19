@preconcurrency import Foundation
@preconcurrency import MSAL

struct MSALAuthResult: Sendable {
    let userId: String
    let email: String
    let idToken: String
    let accountIdentifier: String
    /// Azure AD access token scoped for Microsoft Graph (Files.Read, Sites.Read.All).
    /// Used by MicrosoftGraphRepository to list and download files. Never stored to disk.
    let graphAccessToken: String
}

// @MainActor because MSAL presents its own auth web view and requires main-thread access.
// @unchecked Sendable allows XQAuthOrchestrator (an actor) to hold a reference.
@MainActor
final class MSALAuthProvider: @unchecked Sendable {

    private let clientApplication: MSALPublicClientApplication
    // Files.Read + Sites.Read.All require admin consent in the Azure AD app registration.
    private static let scopes = ["openid", "profile", "email", "User.Read",
                                  "Files.Read", "Files.ReadWrite.All", "Sites.Read.All"]

    init(clientId: String, tenantId: String, bundleId: String) throws {
        let authorityURL = URL(string: "https://login.microsoftonline.com/\(tenantId)")!
        let authority = try MSALAADAuthority(url: authorityURL)
        let config = MSALPublicClientApplicationConfig(
            clientId: clientId,
            redirectUri: "msauth.\(bundleId)://auth",
            authority: authority
        )
        config.knownAuthorities = [authority]
        clientApplication = try MSALPublicClientApplication(configuration: config)
    }

    // Interactive login — presents Microsoft web view.
    func acquireToken(from viewController: UIViewController) async throws -> MSALAuthResult {
        let webParams = MSALWebviewParameters(authPresentationViewController: viewController)
        let params = MSALInteractiveTokenParameters(scopes: Self.scopes, webviewParameters: webParams)
        params.promptType = .selectAccount

        return try await withCheckedThrowingContinuation { continuation in
            clientApplication.acquireToken(with: params) { result, error in
                if let error { continuation.resume(throwing: error); return }
                guard let result, let idToken = result.idToken else {
                    continuation.resume(throwing: AuthError.invalidMSALResponse); return
                }
                continuation.resume(returning: MSALAuthResult(
                    userId: result.account.identifier ?? result.account.username ?? "",
                    email: result.account.username ?? "",
                    idToken: idToken,
                    accountIdentifier: result.account.identifier ?? "",
                    graphAccessToken: result.accessToken
                ))
            }
        }
    }

    // Silent re-auth using cached MSAL account — used on app restart.
    func acquireTokenSilent(accountIdentifier: String) async throws -> MSALAuthResult {
        let accounts = try clientApplication.allAccounts()
        guard let account = accounts.first(where: { $0.identifier == accountIdentifier }) else {
            throw AuthError.noAccountFound
        }
        let authority = try MSALAADAuthority(url: URL(string: "https://login.microsoftonline.com/common")!)
        let params = MSALSilentTokenParameters(scopes: Self.scopes, account: account)
        params.authority = authority

        return try await withCheckedThrowingContinuation { continuation in
            clientApplication.acquireTokenSilent(with: params) { result, error in
                if let error { continuation.resume(throwing: error); return }
                guard let result, let idToken = result.idToken else {
                    continuation.resume(throwing: AuthError.invalidMSALResponse); return
                }
                continuation.resume(returning: MSALAuthResult(
                    userId: result.account.identifier ?? "",
                    email: result.account.username ?? "",
                    idToken: idToken,
                    accountIdentifier: result.account.identifier ?? "",
                    graphAccessToken: result.accessToken
                ))
            }
        }
    }

    func cachedAccountIdentifier() throws -> String? {
        try clientApplication.allAccounts().first?.identifier
    }

    func signOut() throws {
        let accounts = try clientApplication.allAccounts()
        for account in accounts { try clientApplication.remove(account) }
    }
}

enum AuthError: LocalizedError {
    case invalidMSALResponse
    case noAccountFound
    case keychainError(OSStatus)
    case sessionRestoreFailed

    var errorDescription: String? {
        switch self {
        case .invalidMSALResponse: return "The sign-in response was invalid. Please try again."
        case .noAccountFound: return "No signed-in account found. Please sign in."
        case .keychainError(let s): return "Keychain error (\(s)). Please try again."
        case .sessionRestoreFailed: return "Session expired. Please sign in again."
        }
    }
}
