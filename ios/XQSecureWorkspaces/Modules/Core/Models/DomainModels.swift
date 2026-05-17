import Foundation

public enum SensitivityLevel: String, Codable, CaseIterable, Sendable {
    case public_ = "PUBLIC"
    case internal_ = "INTERNAL"
    case confidential = "CONFIDENTIAL"
    case restricted = "RESTRICTED"
}

public struct SecureFile: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let mimeType: String
    public let sizeBytes: Int64
    public let sensitivity: SensitivityLevel
    public let encryptedKeyId: String
    public let sourceProvider: RepositorySource
    public let modifiedAt: Date
    public let riskScore: Int?

    public init(id: UUID, name: String, mimeType: String, sizeBytes: Int64,
                sensitivity: SensitivityLevel, encryptedKeyId: String,
                sourceProvider: RepositorySource, modifiedAt: Date, riskScore: Int?) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.sensitivity = sensitivity
        self.encryptedKeyId = encryptedKeyId
        self.sourceProvider = sourceProvider
        self.modifiedAt = modifiedAt
        self.riskScore = riskScore
    }
}

public enum RepositorySource: String, Codable {
    case sharePoint
    case smb
    case googleDrive
    case localVault
    case xqVault
}

public struct AIEntity: Identifiable, Sendable {
    public let id: UUID
    public let type: EntityType
    public let value: String
    public let confidence: Float
    public let citedControl: CitedControl?

    public enum EntityType: String, Sendable {
        case phi, pii, financial, credential, pciData
    }

    public init(id: UUID, type: EntityType, value: String, confidence: Float, citedControl: CitedControl?) {
        self.id = id
        self.type = type
        self.value = value
        self.confidence = confidence
        self.citedControl = citedControl
    }
}

public struct CitedControl: Hashable, Sendable {
    public let framework: ComplianceFramework
    public let controlId: String
    public let title: String
    public let description: String
    public let enforcement: Enforcement

    public enum ComplianceFramework: String, Sendable { case hipaa, nistSP80053, gdpr, xqPolicy }
    public enum Enforcement: String, Sendable { case block, warn, audit }

    public init(framework: ComplianceFramework, controlId: String, title: String,
                description: String, enforcement: Enforcement) {
        self.framework = framework
        self.controlId = controlId
        self.title = title
        self.description = description
        self.enforcement = enforcement
    }
}

public struct AIClassificationResult: Sendable {
    public let fileId: UUID
    public let sensitivity: SensitivityLevel
    public let riskScore: Int
    public let entities: [AIEntity]
    public let modelVersion: String
    public let processingMs: Int
    public let wasCloudProcessed: Bool

    public init(fileId: UUID, sensitivity: SensitivityLevel, riskScore: Int,
                entities: [AIEntity], modelVersion: String, processingMs: Int, wasCloudProcessed: Bool) {
        self.fileId = fileId
        self.sensitivity = sensitivity
        self.riskScore = riskScore
        self.entities = entities
        self.modelVersion = modelVersion
        self.processingMs = processingMs
        self.wasCloudProcessed = wasCloudProcessed
    }
}

public struct XQSession: Sendable {
    public let userId: String
    public let tenantId: String
    public let accessToken: String
    public let expiresAt: Date
    public let apiVersion: XQAPIVersion

    public init(userId: String, tenantId: String, accessToken: String,
                expiresAt: Date, apiVersion: XQAPIVersion) {
        self.userId = userId
        self.tenantId = tenantId
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.apiVersion = apiVersion
    }
}

public enum XQAPIVersion: String { case v1, v2, v3 }

public struct PolicyBundle: Codable, Sendable {
    public let version: String
    public let signatureHex: String
    public let rules: [PolicyRule]
    public let fetchedAt: Date

    public init(version: String, signatureHex: String, rules: [PolicyRule], fetchedAt: Date) {
        self.version = version
        self.signatureHex = signatureHex
        self.rules = rules
        self.fetchedAt = fetchedAt
    }
}

public struct PolicyRule: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let sensitivity: SensitivityLevel
    public let allowExternalShare: Bool
    public let maxShareExpiryDays: Int?
    public let requireApprovalFromRole: String?
    public let cloudAIPermitted: Bool

    public init(id: UUID, name: String, sensitivity: SensitivityLevel,
                allowExternalShare: Bool, maxShareExpiryDays: Int?,
                requireApprovalFromRole: String?, cloudAIPermitted: Bool) {
        self.id = id
        self.name = name
        self.sensitivity = sensitivity
        self.allowExternalShare = allowExternalShare
        self.maxShareExpiryDays = maxShareExpiryDays
        self.requireApprovalFromRole = requireApprovalFromRole
        self.cloudAIPermitted = cloudAIPermitted
    }
}

public struct AuditEvent: Identifiable, Sendable {
    public let id: UUID
    public let eventType: AuditEventType
    public let fileId: UUID?
    public let actorId: String
    public let timestamp: Date
    public let metadata: [String: String]

    public enum AuditEventType: String, Sendable {
        case fileOpened, fileShared, shareBlocked, screenshotDetected,
             policyApplied, sessionStarted, sessionExpired, aiScanned
    }

    public init(id: UUID, eventType: AuditEventType, fileId: UUID?,
                actorId: String, timestamp: Date, metadata: [String: String]) {
        self.id = id
        self.eventType = eventType
        self.fileId = fileId
        self.actorId = actorId
        self.timestamp = timestamp
        self.metadata = metadata
    }
}
