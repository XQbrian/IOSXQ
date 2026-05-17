import Foundation
import XQCore
import XQRepository
import XQPolicy
import XQFileIntelligence

@MainActor
final class FileBrowserViewModel: ObservableObject {

    @Published var files: [SecureFile] = []
    @Published var filterSensitivity: SensitivityLevel? = nil
    @Published var searchQuery = ""
    @Published var isLoading = false
    @Published var isRefreshing = false

    var filteredFiles: [SecureFile] {
        files.filter { file in
            let matchesSensitivity = filterSensitivity.map { file.sensitivity == $0 } ?? true
            let matchesSearch = searchQuery.isEmpty
                || file.name.localizedCaseInsensitiveContains(searchQuery)
            return matchesSensitivity && matchesSearch
        }
    }

    /// The highest risk score across loaded files. Used to drive the
    /// organisation risk banner. Returns 0 when no files are loaded.
    var orgRiskScore: Int {
        files.compactMap(\.riskScore).max() ?? 0
    }

    /// Number of files currently classified as `.restricted`.
    var restrictedCount: Int {
        files.filter { $0.sensitivity == .restricted }.count
    }

    private let repository: any RepositoryProvider

    init(repository: any RepositoryProvider = SampleDataRepository()) {
        self.repository = repository
    }

    func load(path: String) async {
        isLoading = true
        defer { isLoading = false }
        files = (try? await repository.listFiles(path: path)) ?? []
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        files = (try? await repository.listFiles(path: "/")) ?? []
    }
}
