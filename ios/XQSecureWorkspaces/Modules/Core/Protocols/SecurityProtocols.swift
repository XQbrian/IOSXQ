import Foundation

// Keys generated here never leave the Secure Enclave.
protocol SecureEnclaveManager: Sendable {
    var isAvailable: Bool { get }

    func generateRootKey() async throws -> SecureEnclaveKeyReference
    func deriveKeyEncryptionKey(from root: SecureEnclaveKeyReference) async throws -> Data
    func sign(data: Data, with key: SecureEnclaveKeyReference) async throws -> Data
    func verify(signature: Data, for data: Data, with key: SecureEnclaveKeyReference) async throws -> Bool
    func deleteKey(_ reference: SecureEnclaveKeyReference) async throws
}

struct SecureEnclaveKeyReference: Sendable {
    // The actual key material never crosses this boundary.
    let tag: String
}

protocol JailbreakDetector: Sendable {
    // Returns a confidence score 0–100. >40 = refuse session.
    func assess() async -> JailbreakAssessment
}

struct JailbreakAssessment {
    let confidenceScore: Int
    let signals: [JailbreakSignal]

    enum JailbreakSignal: String {
        case suspiciousFilesystem, dyldInjection, processIntegrityFail,
             behavioralAnomaly, appAttestFail
    }
}

protocol CertificatePinner: Sendable {
    // SPKI hash pinning. Pins are refreshed via remote config without an app update.
    func validate(serverTrust: SecTrust, hostname: String) throws
    func updatePins(_ pins: [String: [String]]) async
}

protocol SessionManager: Sendable {
    var currentSession: XQSession? { get }

    func startSession(credentials: XQCredentials) async throws -> XQSession
    func endSession() async
    func requiresReauthentication() -> Bool
}
