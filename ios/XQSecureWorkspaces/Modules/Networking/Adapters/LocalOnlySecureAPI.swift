import Foundation
import CryptoKit
import XQCore
import Security

/// On-device XQSecureAPI that stores DEKs in the Keychain.
/// Used for local vault operations when the XQ network is unavailable.
public actor LocalOnlySecureAPI: XQSecureAPI {

    public nonisolated let negotiatedVersion: XQAPIVersion = .v3

    public init() {}

    public func authenticate(credentials: XQCredentials) async throws -> XQSession {
        throw XQAPIError.unauthenticated
    }

    public func refreshSession(_ session: XQSession) async throws -> XQSession { session }

    public func revokeSession(_ session: XQSession) async throws {}

    public func encryptFile(data: Data, session: XQSession) async throws -> EncryptedPayload {
        let key = SymmetricKey(size: .bits256)
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(data, using: key, nonce: nonce)
        let keyId = UUID().uuidString
        let dekData = key.withUnsafeBytes { Data($0) }
        try storeKey(keyId: keyId, keyData: dekData)
        return EncryptedPayload(
            ciphertext: sealed.ciphertext,
            iv: Data(nonce),
            authTag: sealed.tag,
            keyId: keyId
        )
    }

    public func decryptFile(_ payload: EncryptedPayload, session: XQSession) async throws -> Data {
        let dekData = try loadKey(keyId: payload.keyId)
        let key = SymmetricKey(data: dekData)
        let nonce = try AES.GCM.Nonce(data: payload.iv)
        let sealed = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: payload.ciphertext,
            tag: payload.authTag
        )
        return try AES.GCM.open(sealed, using: key)
    }

    public func rotateFileKey(fileId: String, session: XQSession) async throws -> EncryptedPayload {
        EncryptedPayload(ciphertext: Data(), iv: Data(), authTag: Data(), keyId: fileId)
    }

    public func fetchPolicyBundle(tenantId: String, session: XQSession) async throws -> PolicyBundle {
        throw XQAPIError.unauthenticated
    }

    public func submitAuditEvent(_ event: AuditEvent, session: XQSession) async throws {}

    // MARK: - Keychain helpers

    private static let service = "com.xqmsg.localvault.dek"

    private func storeKey(keyId: String, keyData: Data) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keyId,
            kSecAttrService: Self.service,
            kSecValueData: keyData,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw XQAPIError.encryptionFailed(
                underlying: NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            )
        }
    }

    private func loadKey(keyId: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keyId,
            kSecAttrService: Self.service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw XQAPIError.encryptionFailed(
                underlying: NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            )
        }
        return data
    }
}
