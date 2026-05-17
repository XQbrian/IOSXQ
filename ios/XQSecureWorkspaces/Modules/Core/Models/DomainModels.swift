import Foundation

enum SensitivityLevel: String, Codable, CaseIterable {
    case public_ = "PUBLIC"
    case internal_ = "INTERNAL"
    case confidential = "CONFIDENTIAL"
    case restricted = "RESTRICTED"
}

struct SecureFile: Identifiable, Hashable {
    let id: UUID
    let name: String
    let mimeType: String
    let sizeBytes: Int64
    let sensitivity: SensitivityLevel
    let encryptedKeyId: String
    let sourceProvider: RepositorySource
    let modifiedAt: Date
    let riskScore: Int?
}

enum RepositorySource: String, Codable {
    case sharePoint
    case smb
    case googleDrive
    case localVault
    case xqVault
}

struct AIEntity: Identifiable {
    let id: UUID
    let type: EntityType
    let value: String
    let confidence: Float
    let citedControl: CitedControl?

    enum EntityType: String {
        case phi, pii, financial, credential, pciData
    }
}

struct CitedControl: Hashable {
    let framework: ComplianceFramework
    let controlId: String
    let title: String
    let description: String
    let enforcement: Enforcement

    enum ComplianceFramework: String { case hipaa, nistSP80053, gdpr, xqPolicy }
    enum Enforcement: String { case block, warn, audit }
}

struct AIClassificationResult {
    let fileId: UUID
    let sensitivity: SensitivityLevel
    let riskScore: Int
    let entities: [AIEntity]
    let modelVersion: String
    let processingMs: Int
    let wasCloudProcessed: Bool
}

struct XQSession {
    let userId: String
    let tenantId: String
    let accessToken: String
    let expiresAt: Date
    let apiVersion: XQAPIVersion
}

enum XQAPIVersion: String { case v1, v2, v3 }

struct PolicyBundle: Codable {
    let version: String
    let signatureHex: String
    let rules: [PolicyRule]
    let fetchedAt: Date
}

struct PolicyRule: Codable, Identifiable {
    let id: UUID
    let name: String
    let sensitivity: SensitivityLevel
    let allowExternalShare: Bool
    let maxShareExpiryDays: Int?
    let requireApprovalFromRole: String?
    let cloudAIPermitted: Bool
}

struct AuditEvent: Identifiable {
    let id: UUID
    let eventType: AuditEventType
    let fileId: UUID?
    let actorId: String
    let timestamp: Date
    let metadata: [String: String]

    enum AuditEventType: String {
        case fileOpened, fileShared, shareBlocked, screenshotDetected,
             policyApplied, sessionStarted, sessionExpired, aiScanned
    }
}
