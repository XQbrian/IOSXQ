import Foundation

@MainActor
final class FileBrowserViewModel: ObservableObject {

    @Published var files: [SecureFile] = []
    @Published var filterSensitivity: SensitivityLevel? = nil
    @Published var searchQuery = ""
    @Published var isLoading = false

    var filteredFiles: [SecureFile] {
        files.filter { file in
            let matchesSensitivity = filterSensitivity.map { file.sensitivity == $0 } ?? true
            let matchesSearch = searchQuery.isEmpty
                || file.name.localizedCaseInsensitiveContains(searchQuery)
            return matchesSensitivity && matchesSearch
        }
    }

    private let repository: any RepositoryProvider

    init(repository: any RepositoryProvider) {
        self.repository = repository
    }

    func load(path: String) async {
        isLoading = true
        defer { isLoading = false }
        files = (try? await repository.listFiles(path: path)) ?? []
    }

    func refresh() async {
        await load(path: "/")
    }
}
