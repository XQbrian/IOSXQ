import Foundation
import XQCore
import XQRepository
import XQFileIntelligence

@MainActor
final class HomeViewModel: ObservableObject {

    struct VaultStats {
        let total: Int
        let confidential: Int
        let restricted: Int
        static let empty = VaultStats(total: 0, confidential: 0, restricted: 0)
    }

    @Published var recentFiles: [SecureFile] = []
    @Published var riskAlerts: [AuditEvent] = []
    @Published var vaultStats: VaultStats = .empty
    @Published var isLoading = false
    @Published var error: String? = nil

    private let repository: any RepositoryProvider
    private let policyEngine: any PolicyEngine

    init(repository: any RepositoryProvider, policyEngine: any PolicyEngine) {
        self.repository = repository
        self.policyEngine = policyEngine
    }

    func loadDashboard() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let files = try await repository.listFiles(path: "/")
            recentFiles = files.sorted { $0.modifiedAt > $1.modifiedAt }

            let confidentialCount = files.filter { $0.sensitivity == .confidential }.count
            let restrictedCount = files.filter { $0.sensitivity == .restricted }.count
            vaultStats = VaultStats(
                total: files.count,
                confidential: confidentialCount,
                restricted: restrictedCount
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}
