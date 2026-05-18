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

    init(
        file: SecureFile,
        rawFileData: Data,
        classificationResult: AIClassificationResult?,
        session: XQSession,
        graphClient: MicrosoftGraphClient?
    ) {
        self.file = file
        self.rawFileData = rawFileData
        self.classificationResult = classificationResult
        self.session = session
        self.graphClient = graphClient
    }

    func send(recipients: [String], expiryDays: Int = 7) async {
        guard !isSending else { return }
        isSending = true
        sendError = nil
        defer { isSending = false }

        do {
            // AES-256-GCM encrypt on device
            let key = SymmetricKey(size: .bits256)
            let payload = rawFileData.isEmpty ? Data("xq-secure-placeholder".utf8) : rawFileData
            let sealedBox = try AES.GCM.seal(payload, using: key)
            guard let encryptedData = sealedBox.combined else {
                sendError = "Encryption failed"
                return
            }

            keyId = key.withUnsafeBytes { ptr -> String in
                Array(ptr.prefix(8)).map { String(format: "%02x", $0) }.joined()
            }

            if let client = graphClient {
                let item = try await client.uploadFileContent(
                    data: encryptedData,
                    name: file.name + ".xqe",
                    mimeType: "application/octet-stream"
                )
                let urlString = try await client.createShareLink(itemId: item.id, expiryDays: expiryDays)
                shareURL = URL(string: urlString)
            }

            sendSuccess = true
        } catch {
            sendError = error.localizedDescription
        }
    }
}
