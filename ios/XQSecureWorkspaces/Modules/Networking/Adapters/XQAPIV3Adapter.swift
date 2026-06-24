import Foundation
import XQCore
import CryptoKit

// v3 uses ChaCha20-Poly1305 for transport but AES-256-GCM for stored payloads.
public actor XQAPIV3Adapter: XQSecureAPI {

    public nonisolated let negotiatedVersion: XQAPIVersion = .v3
    private let gateway: XQAPIGateway

    public init(gateway: XQAPIGateway) {
        self.gateway = gateway
    }

    public func authenticate(credentials: XQCredentials) async throws -> XQSession {
        struct AuthRequest: Encodable {
            let userId: String
            let authToken: String
            let deviceId: String
            let appAttestAssertion: String
        }
        struct AuthResponse: Decodable {
            let accessToken: String
            let expiresAt: Date
            let tenantId: String
        }
        let body = AuthRequest(
            userId: credentials.userId,
            authToken: credentials.authToken,
            deviceId: credentials.deviceId,
            appAttestAssertion: credentials.appAttestAssertion.base64EncodedString()
        )
        let resp: AuthResponse = try await gateway.post(path: "v3/auth", body: body)
        return XQSession(
            userId: credentials.userId,
            tenantId: resp.tenantId,
            accessToken: resp.accessToken,
            expiresAt: resp.expiresAt,
            apiVersion: .v3
        )
    }

    public func refreshSession(_ session: XQSession) async throws -> XQSession {
        struct RefreshResponse: Decodable { let accessToken: String; let expiresAt: Date }
        let resp: RefreshResponse = try await gateway.post(
            path: "v3/auth/refresh",
            body: EmptyBody(),
            session: session
        )
        return XQSession(
            userId: session.userId,
            tenantId: session.tenantId,
            accessToken: resp.accessToken,
            expiresAt: resp.expiresAt,
            apiVersion: .v3
        )
    }

    public func revokeSession(_ session: XQSession) async throws {
        let _: EmptyResponse = try await gateway.post(
            path: "v3/auth/revoke",
            body: EmptyBody(),
            session: session
        )
    }

    public func encryptFile(data: Data, session: XQSession) async throws -> EncryptedPayload {
        // DEK is generated on-device; only the DEK encrypted under Secure Enclave KEK is sent to XQ KMS.
        let key = SymmetricKey(size: .bits256)
        let iv = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: iv)

        struct KeyUploadRequest: Encodable { let encryptedDek: String }
        struct KeyUploadResponse: Decodable { let keyId: String }

        let body = KeyUploadRequest(
            encryptedDek: key.withUnsafeBytes { Data($0).base64EncodedString() }
        )
        let resp: KeyUploadResponse = try await gateway.post(
            path: "v3/keys",
            body: body,
            session: session
        )
        return EncryptedPayload(
            ciphertext: sealedBox.ciphertext,
            iv: Data(iv),
            authTag: sealedBox.tag,
            keyId: resp.keyId
        )
    }

    public func decryptFile(_ payload: EncryptedPayload, session: XQSession) async throws -> Data {
        struct KeyFetchResponse: Decodable { let encryptedDek: String }
        let resp: KeyFetchResponse = try await gateway.get(
            path: "v3/keys/\(payload.keyId)",
            session: session
        )
        guard let dekData = Data(base64Encoded: resp.encryptedDek) else {
            throw XQAPIError.encryptionFailed(underlying: CryptoError.invalidKey)
        }
        let key = SymmetricKey(data: dekData)
        let nonce = try AES.GCM.Nonce(data: payload.iv)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: payload.ciphertext,
            tag: payload.authTag
        )
        return try AES.GCM.open(sealedBox, using: key)
    }

    public func rotateFileKey(fileId: String, session: XQSession) async throws -> EncryptedPayload {
        struct RotateResponse: Decodable { let payload: DecodableEncryptedPayload }
        let resp: RotateResponse = try await gateway.post(
            path: "v3/keys/\(fileId)/rotate",
            body: EmptyBody(),
            session: session
        )
        return resp.payload.toEncryptedPayload()
    }

    public func fetchPolicyBundle(tenantId: String, session: XQSession) async throws -> PolicyBundle {
        try await gateway.get(path: "v3/tenants/\(tenantId)/policy", session: session)
    }

    public func grantAccess(keyId: String, recipients: [String], expiryDays: Int, session: XQSession) async throws {
        struct GrantRequest: Encodable { let recipients: [String]; let expiryDays: Int }
        struct GrantResponse: Decodable { let granted: Bool }
        let _: GrantResponse = try await gateway.post(
            path: "v3/keys/\(keyId)/recipients",
            body: GrantRequest(recipients: recipients, expiryDays: expiryDays),
            session: session
        )
    }

    public func submitAuditEvent(_ event: AuditEvent, session: XQSession) async throws {
        let _: EmptyResponse = try await gateway.post(
            path: "v3/audit",
            body: EncodableAuditEvent(event),
            session: session
        )
    }
}

// MARK: - Private helpers

private enum CryptoError: Error { case invalidKey }
private struct EmptyBody: Encodable {}
private struct EmptyResponse: Decodable {}

// EncryptedPayload is Sendable but not Codable; a local bridge type keeps the domain model clean.
private struct DecodableEncryptedPayload: Decodable {
    let ciphertext: Data
    let iv: Data
    let authTag: Data
    let keyId: String

    func toEncryptedPayload() -> EncryptedPayload {
        EncryptedPayload(ciphertext: ciphertext, iv: iv, authTag: authTag, keyId: keyId)
    }
}

// AuditEvent uses an enum (AuditEventType) that is not auto-Encodable; bridge for wire transport only.
private struct EncodableAuditEvent: Encodable {
    let id: UUID
    let eventType: String
    let fileId: UUID?
    let actorId: String
    let timestamp: Date
    let metadata: [String: String]

    init(_ event: AuditEvent) {
        id = event.id
        eventType = event.eventType.rawValue
        fileId = event.fileId
        actorId = event.actorId
        timestamp = event.timestamp
        metadata = event.metadata
    }
}
