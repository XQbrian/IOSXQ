import Foundation

// Version negotiation happens once at session start; adapter is pinned for session lifetime.
public protocol XQSecureAPI: Sendable {
    var negotiatedVersion: XQAPIVersion { get }

    func authenticate(credentials: XQCredentials) async throws -> XQSession
    func refreshSession(_ session: XQSession) async throws -> XQSession
    func revokeSession(_ session: XQSession) async throws

    func encryptFile(data: Data, session: XQSession) async throws -> EncryptedPayload
    func decryptFile(_ payload: EncryptedPayload, session: XQSession) async throws -> Data
    func rotateFileKey(fileId: String, session: XQSession) async throws -> EncryptedPayload

    func fetchPolicyBundle(tenantId: String, session: XQSession) async throws -> PolicyBundle

    func submitAuditEvent(_ event: AuditEvent, session: XQSession) async throws

    func grantAccess(keyId: String, recipients: [String], expiryDays: Int, session: XQSession) async throws
}

public extension XQSecureAPI {
    func grantAccess(keyId: String, recipients: [String], expiryDays: Int, session: XQSession) async throws {}
}

public struct XQCredentials {
    public let userId: String
    public let authToken: String
    public let deviceId: String
    public let appAttestAssertion: Data

    public init(userId: String, authToken: String, deviceId: String, appAttestAssertion: Data) {
        self.userId = userId
        self.authToken = authToken
        self.deviceId = deviceId
        self.appAttestAssertion = appAttestAssertion
    }
}

public struct EncryptedPayload: Sendable {
    public let ciphertext: Data
    public let iv: Data
    public let authTag: Data
    public let keyId: String

    public init(ciphertext: Data, iv: Data, authTag: Data, keyId: String) {
        self.ciphertext = ciphertext
        self.iv = iv
        self.authTag = authTag
        self.keyId = keyId
    }
}

public enum XQAPIError: Error, LocalizedError {
    case unauthenticated
    case sessionExpired
    case apiVersionMismatch(negotiated: XQAPIVersion, required: XQAPIVersion)
    case policyViolation(rule: String)
    case encryptionFailed(underlying: Error)
    case networkUnavailable
    case rateLimited(retryAfter: TimeInterval)
    case serverError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .policyViolation(let rule): return "Policy violation: \(rule)"
        case .apiVersionMismatch(let n, let r): return "API v\(n.rawValue) cannot satisfy v\(r.rawValue) requirement"
        default: return localizedDescription
        }
    }
}
