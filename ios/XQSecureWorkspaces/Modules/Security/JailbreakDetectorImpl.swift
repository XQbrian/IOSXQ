import Foundation
import XQCore

public actor JailbreakDetectorImpl: JailbreakDetector {

    public init() {}

    public func assess() async -> JailbreakAssessment {
        var score = 0
        var signals: [JailbreakAssessment.JailbreakSignal] = []

        if await checkFilesystem()       { score += 25; signals.append(.suspiciousFilesystem) }
        if await checkDyldInjection()    { score += 25; signals.append(.dyldInjection) }
        if await checkProcessIntegrity() { score += 20; signals.append(.processIntegrityFail) }
        if await checkBehavioral()       { score += 15; signals.append(.behavioralAnomaly) }
        // App Attest failure is assessed separately during session establishment.

        return JailbreakAssessment(confidenceScore: min(score, 100), signals: signals)
    }

    private func checkFilesystem() async -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private func checkDyldInjection() async -> Bool {
        // DYLD_INSERT_LIBRARIES is stripped by the OS on stock devices.
        return ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"] != nil
    }

    private func checkProcessIntegrity() async -> Bool {
        // On stock devices the sandbox prevents spawning children.
        // We check for sshd and other daemons that only run post-jailbreak.
        let jailbreakDaemons = ["/usr/sbin/sshd", "/usr/bin/ssh", "/usr/local/bin/cycript"]
        return jailbreakDaemons.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private func checkBehavioral() async -> Bool {
        let testPath = "/private/testXQ_\(UUID().uuidString)"
        let canWrite = (try? "x".write(toFile: testPath, atomically: true, encoding: .utf8)) != nil
        if canWrite { try? FileManager.default.removeItem(atPath: testPath) }
        return canWrite
    }
}
