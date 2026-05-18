import Foundation
import XQCore

/// RepositoryProvider backed by Microsoft Graph (OneDrive + SharePoint).
/// Combines OneDrive root items with the first SharePoint document library
/// found in the tenant, so the file browser shows a unified view.
final class MicrosoftGraphRepository: RepositoryProvider, @unchecked Sendable {

    var source: RepositorySource { .sharePoint }
    var isAvailableOffline: Bool { false }

    private let client: MicrosoftGraphClient

    init(graphToken: String) {
        client = MicrosoftGraphClient(graphToken: graphToken)
    }

    // MARK: - RepositoryProvider

    func listFiles(path: String) async throws -> [SecureFile] {
        async let oneDriveItems = fetchOneDriveFiles()
        async let sharePointItems = fetchSharePointFiles()

        let (od, sp) = try await (oneDriveItems, sharePointItems)
        return od + sp
    }

    func fetchFile(_ file: SecureFile) async throws -> Data {
        try await client.downloadFileContent(encryptedKeyId: file.encryptedKeyId)
    }

    func uploadFile(data: Data, name: String, path: String, session: XQSession) async throws -> SecureFile {
        throw RepositoryError.encryptionRequiredBeforeUpload
    }

    func deleteFile(_ file: SecureFile, session: XQSession) async throws {
        throw RepositoryError.authenticationRequired
    }

    func deltaSync(since cursor: SyncCursor?) async throws -> DeltaSyncResult {
        let files = try await listFiles(path: "/")
        return DeltaSyncResult(
            added: files,
            modified: [],
            deleted: [],
            nextCursor: SyncCursor(
                token: "graph-delta-\(Date().timeIntervalSince1970)",
                fetchedAt: Date(),
                provider: .sharePoint
            )
        )
    }

    // MARK: - Private Fetch Helpers

    private func fetchOneDriveFiles() async throws -> [SecureFile] {
        let items = try await client.listOneDriveRoot()
        return items.compactMap { item in
            guard item.file != nil else { return nil }
            return graphItemToSecureFile(item, driveId: nil, source: .sharePoint)
        }
    }

    private func fetchSharePointFiles() async throws -> [SecureFile] {
        guard let site = (try? await client.listSites())?.first else { return [] }
        let drives = (try? await client.listSiteDrives(siteId: site.id)) ?? []
        guard let drive = drives.first(where: { $0.driveType == "documentLibrary" }) ?? drives.first
        else { return [] }

        let items = (try? await client.listSharePointDriveRoot(driveId: drive.id)) ?? []
        return items.compactMap { item in
            guard item.file != nil else { return nil }
            return graphItemToSecureFile(item, driveId: drive.id, source: .sharePoint)
        }
    }

    // MARK: - Model Mapping

    private func graphItemToSecureFile(
        _ item: GraphDriveItem,
        driveId: String?,
        source: RepositorySource
    ) -> SecureFile {
        let encryptedKeyId: String
        if let driveId {
            encryptedKeyId = "\(driveId):\(item.id)"
        } else {
            encryptedKeyId = item.id
        }

        let mimeType = item.file?.mimeType ?? mimeTypeFromName(item.name)
        let modifiedAt = MicrosoftGraphClient.parseDate(item.lastModifiedDateTime)
        let uuid = MicrosoftGraphClient.stableUUID(from: item.id)

        return SecureFile(
            id: uuid,
            name: item.name,
            mimeType: mimeType,
            sizeBytes: item.size ?? 0,
            sensitivity: inferSensitivity(from: item.name),
            encryptedKeyId: encryptedKeyId,
            sourceProvider: source,
            modifiedAt: modifiedAt,
            riskScore: nil
        )
    }

    private func inferSensitivity(from name: String) -> SensitivityLevel {
        let lower = name.lowercased()
        if lower.contains("confidential") || lower.contains("restricted") || lower.contains("phi") ||
           lower.contains("patient") || lower.contains("hipaa") { return .restricted }
        if lower.contains("internal") || lower.contains("private") || lower.contains("secret") { return .confidential }
        return .internal_
    }

    private func mimeTypeFromName(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":   return "application/pdf"
        case "docx":  return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xlsx":  return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "pptx":  return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "doc":   return "application/msword"
        case "xls":   return "application/vnd.ms-excel"
        case "ppt":   return "application/vnd.ms-powerpoint"
        case "txt":   return "text/plain"
        case "png":   return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "mp4":   return "video/mp4"
        case "zip":   return "application/zip"
        default:      return "application/octet-stream"
        }
    }
}
