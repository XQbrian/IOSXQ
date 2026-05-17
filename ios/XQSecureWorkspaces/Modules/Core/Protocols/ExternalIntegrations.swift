import Foundation

public protocol SharePointProvider: RepositoryProvider {
    func authenticate(tenantId: String, clientId: String) async throws -> SharePointSession
    func listSites() async throws -> [SharePointSite]
    func fetchDriveItems(siteId: String, driveId: String, path: String) async throws -> [SecureFile]
}

public struct SharePointSession {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let tenantId: String

    public init(accessToken: String, refreshToken: String, expiresAt: Date, tenantId: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tenantId = tenantId
    }
}

public struct SharePointSite: Identifiable {
    public let id: String
    public let displayName: String
    public let webUrl: String

    public init(id: String, displayName: String, webUrl: String) {
        self.id = id
        self.displayName = displayName
        self.webUrl = webUrl
    }
}

public protocol IdentityProvider: Sendable {
    var providerType: IDPType { get }

    func authenticate(tenantId: String) async throws -> IdentityClaims
    func refreshClaims(_ claims: IdentityClaims) async throws -> IdentityClaims
    func signOut() async throws
}

public enum IDPType { case entraID, okta, googleWorkspace, xqNative }

public struct IdentityClaims: Sendable {
    public let userId: String
    public let email: String
    public let tenantId: String
    public let roles: [String]
    public let expiresAt: Date

    public init(userId: String, email: String, tenantId: String, roles: [String], expiresAt: Date) {
        self.userId = userId
        self.email = email
        self.tenantId = tenantId
        self.roles = roles
        self.expiresAt = expiresAt
    }
}
