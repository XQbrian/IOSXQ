import Foundation

// Version negotiation happens once at session start; adapter is pinned for session lifetime.
protocol XQSecureAPI: Sendable {
    var negotiatedVersion: XQAPIVersion { get }

    func authenticate(credentials: XQCredentials) async throws -> XQSession
    func refreshSession(_ session: XQSession) async throws -> XQSession
    func revokeSession(_ session: XQSession) async throws

    func encryptFile(data: Data, session: XQSession) async throws -> EncryptedPayload
    func decryptFile(_ payload: EncryptedPayload, session: XQSession) async throws -> Data
    func rotateFileKey(fileId: String, session: XQSession) async throws -> EncryptedPayload

    func fetchPolicyBundle(tenantId: String, session: XQSession) async throws -> PolicyBundle

    func submitAuditEvent(_ event: AuditEvent, session: XQSession) async throws
}

struct XQCredentials {
    let userId: String
    let authToken: String
    let deviceId: String
    let appAttestAssertion: Data
}

struct EncryptedPayload: Sendable {
    let ciphertext: Data
    let iv: Data
    let authTag: Data
    let keyId: String
}

enum XQAPIError: Error, LocalizedError {
    case unauthenticated
    case sessionExpired
    case apiVersionMismatch(negotiated: XQAPIVersion, required: XQAPIVersion)
    case policyViolation(rule: String)
    case encryptionFailed(underlying: Error)
    case networkUnavailable
    case rateLimited(retryAfter: TimeInterval)
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .policyViolation(let rule): return "Policy violation: \(rule)"
        case .apiVersionMismatch(let n, let r): return "API v\(n.rawValue) cannot satisfy v\(r.rawValue) requirement"
        default: return localizedDescription
        }
    }
}
