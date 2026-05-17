import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = FileBrowserViewModel(repository: StubFileBrowserRepository())

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: "All",
                            isSelected: vm.filterSensitivity == nil
                        ) {
                            vm.filterSensitivity = nil
                        }

                        ForEach(SensitivityLevel.allCases, id: \.self) { level in
                            FilterChip(
                                label: level.chipLabel,
                                isSelected: vm.filterSensitivity == level
                            ) {
                                vm.filterSensitivity = level
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemBackground))

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        // SharePoint section
                        let sharePointFiles = vm.filteredFiles.filter { $0.sourceProvider == .sharePoint }
                        if !sharePointFiles.isEmpty {
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(sharePointFiles) { file in
                                        Button {
                                            coordinator.navigate(to: .fileViewer(file))
                                        } label: {
                                            FileRowView(file: file)
                                                .background(Color(.systemBackground))
                                        }
                                        .buttonStyle(.plain)

                                        if file.id != sharePointFiles.last?.id {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            } header: {
                                SectionHeader(title: "SharePoint — Acme Corp")
                            }
                        }

                        // Local Vault section
                        let localFiles = vm.filteredFiles.filter { $0.sourceProvider == .localVault || $0.sourceProvider == .xqVault }
                        if !localFiles.isEmpty {
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(localFiles) { file in
                                        Button {
                                            coordinator.navigate(to: .fileViewer(file))
                                        } label: {
                                            FileRowView(file: file)
                                                .background(Color(.systemBackground))
                                        }
                                        .buttonStyle(.plain)

                                        if file.id != localFiles.last?.id {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            } header: {
                                SectionHeader(title: "Local Vault")
                            }
                        }

                        // All files fallback (other sources)
                        let otherFiles = vm.filteredFiles.filter {
                            $0.sourceProvider != .sharePoint &&
                            $0.sourceProvider != .localVault &&
                            $0.sourceProvider != .xqVault
                        }
                        if !otherFiles.isEmpty {
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(otherFiles) { file in
                                        Button {
                                            coordinator.navigate(to: .fileViewer(file))
                                        } label: {
                                            FileRowView(file: file)
                                                .background(Color(.systemBackground))
                                        }
                                        .buttonStyle(.plain)

                                        if file.id != otherFiles.last?.id {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            } header: {
                                SectionHeader(title: "Other Sources")
                            }
                        }

                        if vm.filteredFiles.isEmpty && !vm.isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("No files found")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await vm.refresh()
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        coordinator.navigate(to: .aiImport)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(brandBlue)
                    }
                }
            }
            .searchable(text: $vm.searchQuery, prompt: "Search files…")
            .task {
                await vm.load(path: "/")
            }
        }
    }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGroupedBackground))
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? brandBlue : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? Color(red: 0.910, green: 0.918, blue: 0.992)
                              : Color(.systemFill))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stub

private extension SensitivityLevel {
    var chipLabel: String {
        switch self {
        case .public_: return "Public"
        case .internal_: return "Internal"
        case .confidential: return "Confidential"
        case .restricted: return "Restricted"
        }
    }
}

private final class StubFileBrowserRepository: RepositoryProvider {
    var source: RepositorySource { .sharePoint }
    var isAvailableOffline: Bool { false }
    func listFiles(path: String) async throws -> [SecureFile] { [] }
    func fetchFile(_ file: SecureFile) async throws -> Data { Data() }
    func uploadFile(data: Data, name: String, path: String, session: XQSession) async throws -> SecureFile {
        throw RepositoryError.authenticationRequired
    }
    func deleteFile(_ file: SecureFile, session: XQSession) async throws {}
    func deltaSync(since cursor: SyncCursor?) async throws -> DeltaSyncResult {
        DeltaSyncResult(added: [], modified: [], deleted: [],
                        nextCursor: SyncCursor(token: "", fetchedAt: Date(), provider: .sharePoint))
    }
}

#Preview {
    FileBrowserView()
        .environmentObject(AppCoordinator())
}
