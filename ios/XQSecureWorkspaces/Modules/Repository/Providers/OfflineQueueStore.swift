import Foundation

// MARK: - OfflineOperation + Codable

extension OfflineOperation: Codable {

    private enum DiscriminatorKey: String, CodingKey { case type }
    private enum TypeTag: String, Codable { case upload, delete }

    // Intermediate structs used as the discriminated-union payload.

    private struct UploadPayload: Codable {
        let id: UUID
        /// PRODUCTION NOTE: Storing raw Data in the queue file is convenient for
        /// a prototype but can be large. In production, write the encrypted blob
        /// to SecureFileStore first and persist only the URL here.
        let data: Data
        let name: String
        let path: String
        let provider: RepositorySource
    }

    private struct DeletePayload: Codable {
        let id: UUID
        let fileId: UUID
        let provider: RepositorySource
    }

    // MARK: Encodable

    func encode(to encoder: Encoder) throws {
        switch self {
        case .upload(let id, let data, let name, let path, let provider):
            var container = encoder.singleValueContainer()
            let payload = UploadPayload(id: id, data: data, name: name, path: path, provider: provider)
            // Wrap in a tagged object so the decoder can discriminate.
            var keyed = encoder.container(keyedBy: TaggedCodingKeys.self)
            try keyed.encode(TypeTag.upload, forKey: .type)
            try keyed.encode(payload, forKey: .payload)
            _ = container // suppress unused warning; keyed container does the work
        case .delete(let id, let fileId, let provider):
            var keyed = encoder.container(keyedBy: TaggedCodingKeys.self)
            try keyed.encode(TypeTag.delete, forKey: .type)
            let payload = DeletePayload(id: id, fileId: fileId, provider: provider)
            try keyed.encode(payload, forKey: .payload)
        }
    }

    // MARK: Decodable

    init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: TaggedCodingKeys.self)
        let tag = try keyed.decode(TypeTag.self, forKey: .type)
        switch tag {
        case .upload:
            let p = try keyed.decode(UploadPayload.self, forKey: .payload)
            self = .upload(id: p.id, data: p.data, name: p.name, path: p.path, provider: p.provider)
        case .delete:
            let p = try keyed.decode(DeletePayload.self, forKey: .payload)
            self = .delete(id: p.id, fileId: p.fileId, provider: p.provider)
        }
    }

    private enum TaggedCodingKeys: String, CodingKey { case type, payload }
}

// MARK: - OfflineQueueStore

/// Persists the offline operation queue to disk so queued mutations survive
/// app restarts. All data is written under NSFileProtectionComplete so the
/// queue file is inaccessible while the device is locked.
actor OfflineQueueStore {

    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        // Ensure the directory exists with NSFileProtectionComplete so that
        // every file created inside inherits the protection class.
        let dir = appSupport
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [FileAttributeKey.protectionKey: FileProtectionType.complete]
        )

        storageURL = dir.appendingPathComponent("xq_offline_queue.json")

        // Set file protection explicitly on the queue file itself so the
        // guarantee holds even if it was created before this init ran.
        if FileManager.default.fileExists(atPath: storageURL.path) {
            try? (storageURL as NSURL).setResourceValue(
                FileProtectionType.complete,
                forKey: .fileProtectionKey
            )
        }
    }

    // MARK: - Persistence

    /// Serialises the operation queue to JSON and atomically writes it to disk.
    ///
    /// PRODUCTION NOTE: UploadPayload embeds raw Data which can be several MB
    /// per operation. Replace with a SecureFileStore URL reference before
    /// shipping to reduce peak memory usage and queue file size.
    func save(operations: [OfflineOperation]) async throws {
        let data = try JSONEncoder.xq.encode(operations)
        try data.write(to: storageURL, options: .atomicWrite)

        // Re-apply file protection after every write; atomicWrite may create a
        // new inode, which resets the protection class to the default.
        try (storageURL as NSURL).setResourceValue(
            FileProtectionType.complete,
            forKey: .fileProtectionKey
        )
    }

    /// Deserialises the operation queue from disk. Returns an empty array when
    /// the queue file does not yet exist (first launch or after a successful
    /// full drain).
    func load() async throws -> [OfflineOperation] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }
        let data = try Data(contentsOf: storageURL)
        return try JSONDecoder.xq.decode([OfflineOperation].self, from: data)
    }
}

// MARK: - Shared JSON coders (local scope to avoid re-declaration conflicts)

// JSONEncoder.xq and JSONDecoder.xq are defined in XQAPIGateway.swift and are
// visible across the module, so no redeclaration is needed here.
