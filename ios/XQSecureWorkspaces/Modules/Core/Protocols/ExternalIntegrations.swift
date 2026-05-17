import Foundation

protocol SharePointProvider: RepositoryProvider {
    func authenticate(tenantId: String, clientId: String) async throws -> SharePointSession
    func listSites() async throws -> [SharePointSite]
    func fetchDriveItems(siteId: String, driveId: String, path: String) async throws -> [SecureFile]
}

struct SharePointSession {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let tenantId: String
}

struct SharePointSite: Identifiable {
    let id: String
    let displayName: String
    let webUrl: String
}

protocol IdentityProvider: Sendable {
    var providerType: IDPType { get }

    func authenticate(tenantId: String) async throws -> IdentityClaims
    func refreshClaims(_ claims: IdentityClaims) async throws -> IdentityClaims
    func signOut() async throws
}

enum IDPType { case entraID, okta, googleWorkspace, xqNative }

struct IdentityClaims: Sendable {
    let userId: String
    let email: String
    let tenantId: String
    let roles: [String]
    let expiresAt: Date
}
