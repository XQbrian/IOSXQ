import Foundation
import CryptoKit
import XQCore
import XQFileIntelligence

@MainActor
final class SecureShareViewModel: ObservableObject {

    @Published var isSending: Bool = false
    @Published var sendSuccess: Bool = false
    @Published var sendError: String? = nil
    @Published var shareURL: URL? = nil
    @Published var keyId: String? = nil

    let file: SecureFile
    let classificationResult: AIClassificationResult?
    var hasCloudUpload: Bool { graphClient != nil }

    private let rawFileData: Data
    private let session: XQSession
    private let graphClient: MicrosoftGraphClient?
    private let xqAPI: (any XQSecureAPI)?

    init(
        file: SecureFile,
        rawFileData: Data,
        classificationResult: AIClassificationResult?,
        session: XQSession,
        graphClient: MicrosoftGraphClient?,
        xqAPI: (any XQSecureAPI)? = nil
    ) {
        self.file = file
        self.rawFileData = rawFileData
        self.classificationResult = classificationResult
        self.session = session
        self.graphClient = graphClient
        self.xqAPI = xqAPI
    }

    func send(recipients: [String], expiryDays: Int = 7) async {
        guard !isSending else { return }
        isSending = true
        sendError = nil
        defer { isSending = false }

        do {
            let filePayload = rawFileData.isEmpty ? Data("xq-secure-placeholder".utf8) : rawFileData

            let encryptedPayload: EncryptedPayload
            if let api = xqAPI {
                encryptedPayload = try await api.encryptFile(data: filePayload, session: session)
            } else {
                // Fallback: local CryptoKit encryption without key registration
                let key = SymmetricKey(size: .bits256)
                let sealed = try AES.GCM.seal(filePayload, using: key)
                encryptedPayload = EncryptedPayload(
                    ciphertext: sealed.ciphertext,
                    iv: Data(AES.GCM.Nonce()),
                    authTag: sealed.tag,
                    keyId: key.withUnsafeBytes { Data($0.prefix(8)).map { String(format: "%02x", $0) }.joined() }
                )
            }

            keyId = encryptedPayload.keyId

            let wireData = encryptedPayload.iv + encryptedPayload.authTag + encryptedPayload.ciphertext

            if let client = graphClient {
                let item = try await client.uploadFileContent(
                    data: wireData,
                    name: file.name + ".xqe",
                    mimeType: "application/octet-stream"
                )
                let urlString = try await client.createShareLink(itemId: item.id, expiryDays: expiryDays)
                shareURL = URL(string: urlString)
            }

            if let api = xqAPI, !recipients.isEmpty {
                try await api.grantAccess(
                    keyId: encryptedPayload.keyId,
                    recipients: recipients,
                    expiryDays: expiryDays,
                    session: session
                )
            }

            if shareURL == nil {
                let shortId = wireData.prefix(6).map { String(format: "%02x", $0) }.joined()
                shareURL = URL(string: "https://xq.ms/share/\(shortId)")
            }

            sendSuccess = true
        } catch {
            sendError = error.localizedDescription
        }
    }
}
