import Foundation
import XQCore

// Persists only non-sensitive session metadata to the device Keychain.
// The accessToken is NEVER stored here — it lives in memory only, per security spec.
actor KeychainSessionStore {

    private let service = "com.xqmsg.ios.secureworkspaces.session"
    private let account = "active-session"

    // Stored fields (no accessToken):
    // userId, tenantId, expiresAt (ISO-8601), apiVersion, msalAccountIdentifier
    struct SessionMetadata: Codable {
        let userId: String
        let tenantId: String
        let expiresAt: Date
        let apiVersion: String
        let msalAccountIdentifier: String
    }

    func save(session: XQSession, msalAccountIdentifier: String) throws {
        let metadata = SessionMetadata(
            userId: session.userId,
            tenantId: session.tenantId,
            expiresAt: session.expiresAt,
            apiVersion: session.apiVersion.rawValue,
            msalAccountIdentifier: msalAccountIdentifier
        )
        let data = try JSONEncoder.iso.encode(metadata)
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(q as CFDictionary)
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw AuthError.keychainError(status) }
    }

    func load() throws -> SessionMetadata? {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try JSONDecoder.iso.decode(SessionMetadata.self, from: data)
    }

    func clear() {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(q as CFDictionary)
    }

    func hasUnexpiredMetadata() -> Bool {
        guard let metadata = try? load() else { return false }
        return metadata.expiresAt > Date().addingTimeInterval(300)
    }
}

private extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
}

private extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}
