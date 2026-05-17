import Foundation
import XQCore

public actor SecureFileStore {

    private let enclaveManager: any SecureEnclaveManager

    public init(enclaveManager: any SecureEnclaveManager) {
        self.enclaveManager = enclaveManager
    }

    public func write(payload: EncryptedPayload, fileName: String) async throws -> URL {
        let url = protectedURL(for: fileName)
        var raw = Data()
        raw.append(payload.iv)
        raw.append(payload.authTag)
        raw.append(payload.ciphertext)

        try raw.write(to: url)

        // NSFileProtectionComplete is set explicitly rather than relying on the
        // default protection class so the guarantee is visible at the call site.
        try (url as NSURL).setResourceValue(
            FileProtectionType.complete,
            forKey: .fileProtectionKey
        )

        return url
    }

    public func read(from url: URL) async throws -> EncryptedPayload {
        let raw = try Data(contentsOf: url)
        guard raw.count > 28 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let iv = raw.prefix(12)
        let authTag = raw[12..<28]
        let ciphertext = raw.suffix(from: 28)
        return EncryptedPayload(
            ciphertext: ciphertext,
            iv: iv,
            authTag: authTag,
            keyId: url.deletingPathExtension().lastPathComponent
        )
    }

    public func delete(at url: URL) async throws {
        try FileManager.default.removeItem(at: url)
    }

    private func protectedURL(for fileName: String) -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let vault = appSupport.appendingPathComponent("XQVault", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: vault,
            withIntermediateDirectories: true,
            attributes: [
                FileAttributeKey.protectionKey: FileProtectionType.complete
            ]
        )
        return vault.appendingPathComponent(fileName)
    }
}
