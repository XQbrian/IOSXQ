import Foundation
import XQCore

/// On-device sender profile store. Profiles are keyed by email address and
/// held in memory for the app session. Nothing is persisted to disk or transmitted.
public actor LocalSenderProfileStore: SenderProfileStore {

    private var profiles: [String: SenderProfile] = [:]

    public init() {}

    public func profile(for email: String, tenantId: String) async -> SenderProfile? {
        profiles[email]
    }

    public func updateProfile(_ profile: SenderProfile, tenantId: String) async throws {
        profiles[profile.email] = profile
    }

    public func orgGraphDistance(from actorId: String, to targetEmail: String, tenantId: String) async -> Int? {
        nil
    }
}
