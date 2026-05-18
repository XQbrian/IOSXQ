import Foundation
import DeviceCheck
import CryptoKit

// Wraps DCAppAttestService. On simulator / unsupported hardware, returns empty
// assertion so development builds can run without App Attest support.
actor AppAttestService {

    private let keychainService = "com.xqmsg.ios.secureworkspaces.attest-key-id"
    var isSupported: Bool { DCAppAttestService.shared.isSupported }

    // Returns assertion data for the given clientData payload.
    func createAssertion(for clientData: Data) async throws -> Data {
        guard DCAppAttestService.shared.isSupported else { return Data() }
        let id = try await resolveKeyId()
        let hash = Data(SHA256.hash(data: clientData))
        return try await DCAppAttestService.shared.generateAssertion(id, clientDataHash: hash)
    }

    // One-time key attestation against Apple's servers using a server-issued challenge.
    func attestKey(challenge: Data) async throws -> Data {
        guard DCAppAttestService.shared.isSupported else { return Data() }
        let id = try await resolveKeyId()
        let hash = Data(SHA256.hash(data: challenge))
        return try await DCAppAttestService.shared.attestKey(id, clientDataHash: hash)
    }

    private func resolveKeyId() async throws -> String {
        if let existing = loadKeyIdFromKeychain() { return existing }
        let newId = try await DCAppAttestService.shared.generateKey()
        saveKeyIdToKeychain(newId)
        return newId
    }

    private func loadKeyIdFromKeychain() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveKeyIdToKeychain(_ id: String) {
        guard let data = id.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
