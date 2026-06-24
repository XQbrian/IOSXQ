import SwiftUI
import XQCore
import XQRepository
import XQFileIntelligence

// MARK: - Files Tab enums

enum FilesTab: String, CaseIterable {
    case folders = "Folders"
    case recent  = "Recent"
    case shared  = "Shared"
    case vault   = "Vault"
}

enum SmartViewFilter: String, CaseIterable {
    case allSources  = "All Sources"
    case department  = "Department"
    case sensitivity = "Sensitivity"
    case ai          = "AI"
}

enum FilesViewMode { case grid, list }

// MARK: - FileBrowserView

struct FileBrowserView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = FileBrowserViewModel()

    @State private var navigationPath = NavigationPath()
    @State private var selectedFilesTab: FilesTab = .folders
    @State private var selectedSmartView: SmartViewFilter = .allSources
    @State private var viewMode: FilesViewMode = .grid
    @State private var showSemanticSearch = false
    @State private var showRiskDashboard  = false
    @State private var showAIImport       = false
    @FocusState private var searchFocused: Bool

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let aiPurple  = Color(red: 0.686, green: 0.322, blue: 0.871)

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                innerTabBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                Divider()

                switch selectedFilesTab {
                case .folders: foldersTab
                case .recent:  recentTab
                case .shared:  sharedStub
                case .vault:   vaultTab
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        Button { showSemanticSearch = true } label: {
                            Image(systemName: AppIcon.semanticSearch)
                                .font(.system(size: 17)).foregroundColor(brandBlue)
                        }
                        Button { showAIImport = true } label: {
                            Image(systemName: AppIcon.add)
                                .font(.system(size: 17, weight: .semibold)).foregroundColor(brandBlue)
                        }
                    }
                }
            }
            .navigationDestination(for: SecureFile.self) { file in FileViewerView(file: file) }
            .navigationDestination(for: FolderItem.self) { folder in FolderView(folder: folder) }
            .sheet(isPresented: $showSemanticSearch) { SemanticSearchView() }
            .sheet(isPresented: $showRiskDashboard)  { FileRiskDashboardView() }
            .sheet(isPresented: $showAIImport)       { AIImportView() }
            .task {
                if let repo = coordinator.repository { vm.configure(repository: repo) }
                await vm.load(path: "/")
            }
        }
    }

    // MARK: - Inner tab bar

    private var innerTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(FilesTab.allCases, id: \.self) { tab in
                    FilesTabPill(label: tab.rawValue, isSelected: selectedFilesTab == tab) {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedFilesTab = tab }
                    }
                }
            }
        }
    }

    // MARK: - Folders tab

    private var foldersTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                AISemanticSearchBar(
                    text: $vm.searchQuery,
                    isFocused: $searchFocused,
                    onSubmit: { showSemanticSearch = true }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

                smartViewRow
                    .padding(.bottom, 8)

                HStack {
                    if vm.orgRiskScore > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Text("\(vm.restrictedCount) restricted")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                    viewModeToggle
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                pinnedSection

                ForEach(FolderSourceGroup.samples) { group in
                    SourceGroupSection(group: group)
                }

                Spacer(minLength: 32)
            }
        }
        .refreshable { await vm.refresh() }
    }

    // MARK: - Smart View pills

    private var smartViewRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SmartViewFilter.allCases, id: \.self) { filter in
                    FilterChip(label: filter.rawValue, isSelected: selectedSmartView == filter) {
                        selectedSmartView = filter
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - View mode toggle

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            Button { withAnimation { viewMode = .grid } } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(viewMode == .grid ? brandBlue : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 16)

            Button { withAnimation { viewMode = .list } } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(viewMode == .list ? brandBlue : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Pinned 2×2 grid

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pinned")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.3)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(FolderItem.pinned) { folder in
                    NavigationLink(value: folder) {
                        FolderCard(folder: folder)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Recent tab

    private var recentTab: some View {
        List {
            Section {
                ForEach(vm.filteredFiles.prefix(4)) { file in
                    NavigationLink(value: file) {
                        RecentFileRow(file: file)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            Section {
                ForEach(vm.filteredFiles.dropFirst(4).prefix(6)) { file in
                    NavigationLink(value: file) {
                        RecentFileRow(file: file)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Yesterday")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Shared stub

    private var sharedStub: some View {
        FilesStubView(icon: "square.and.arrow.up.fill",
                      title: "Shared",
                      subtitle: "Files and links shared with others")
    }

    // MARK: - Vault tab

    private var vaultTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 18))
                        .foregroundColor(aiPurple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AES-256-GCM Encrypted")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("All vault files are encrypted on-device. Keys never leave the Secure Enclave.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(aiPurple.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(aiPurple.opacity(0.2), lineWidth: 0.5))
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                VStack(spacing: 0) {
                    ForEach(Array(FolderItem.pinned.enumerated()), id: \.element.id) { idx, folder in
                        NavigationLink(value: folder) {
                            VaultFolderRow(folder: folder)
                        }
                        .buttonStyle(.plain)
                        if idx < FolderItem.pinned.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                .padding(.horizontal, 16)

                Spacer(minLength: 32)
            }
        }
    }
}

// MARK: - Source Group Model

struct SourceFolder: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let source: String
    let icon: String
    let accentColor: Color
    let fileCount: Int
    let activity: String

    static func == (lhs: SourceFolder, rhs: SourceFolder) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct FolderSourceGroup: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let accentColor: Color
    let folders: [SourceFolder]

    static let samples: [FolderSourceGroup] = [
        FolderSourceGroup(
            name: "SharePoint",
            icon: "building.2.fill",
            accentColor: .blue,
            folders: [
                SourceFolder(name: "Legal Team Site", source: "SharePoint · Legal",
                             icon: "building.columns.fill", accentColor: .red,
                             fileCount: 14, activity: "edited 2h ago"),
                SourceFolder(name: "Engineering Projects", source: "SharePoint · Engineering",
                             icon: "cpu.fill", accentColor: .blue,
                             fileCount: 28, activity: "synced 30m ago"),
                SourceFolder(name: "Compliance Center", source: "SharePoint · Compliance",
                             icon: "checkmark.seal.fill", accentColor: .green,
                             fileCount: 9, activity: "edited yesterday"),
            ]
        ),
        FolderSourceGroup(
            name: "OneDrive",
            icon: "icloud.fill",
            accentColor: Color(red: 0.0, green: 0.478, blue: 1.0),
            folders: [
                SourceFolder(name: "Personal Files", source: "OneDrive · Personal",
                             icon: "person.fill",
                             accentColor: Color(red: 0.0, green: 0.478, blue: 1.0),
                             fileCount: 22, activity: "edited 4h ago"),
                SourceFolder(name: "Shared with Me", source: "OneDrive · Shared",
                             icon: "person.2.fill", accentColor: .teal,
                             fileCount: 7, activity: "new file today"),
            ]
        ),
        FolderSourceGroup(
            name: "Vault",
            icon: "lock.shield.fill",
            accentColor: Color(red: 0.686, green: 0.322, blue: 0.871),
            folders: [
                SourceFolder(name: "Patient Records", source: "XQ Vault · Restricted",
                             icon: "cross.case.fill", accentColor: .red,
                             fileCount: 7, activity: "encrypted just now"),
                SourceFolder(name: "Confidential Contracts", source: "XQ Vault · Confidential",
                             icon: "doc.fill", accentColor: .orange,
                             fileCount: 5, activity: "edited 3d ago"),
            ]
        ),
    ]
}

// MARK: - Source Group Section (collapsible)

private struct SourceGroupSection: View {
    let group: FolderSourceGroup
    @State private var isCollapsed = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(group.accentColor.opacity(0.12))
                            .frame(width: 22, height: 22)
                        Image(systemName: group.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(group.accentColor)
                    }
                    Text(group.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.3)
                    Spacer()
                    Text("\(group.folders.count) folders")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                VStack(spacing: 8) {
                    ForEach(group.folders) { folder in
                        NavigationLink(value: FolderItem(
                            name: folder.name, icon: folder.icon,
                            accentColor: folder.accentColor,
                            sensitivity: .internal_, fileCount: folder.fileCount,
                            subfolders: [], statusDot: .none)
                        ) {
                            SourceFolderCard(folder: folder)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Source Folder Card (left bar + icon + name + source + count)

private struct SourceFolderCard: View {
    let folder: SourceFolder

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(folder.accentColor)
                .frame(width: 3)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 12, bottomLeadingRadius: 12,
                    bottomTrailingRadius: 0, topTrailingRadius: 0
                ))

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(folder.accentColor.opacity(0.10))
                        .frame(width: 34, height: 34)
                    Image(systemName: folder.icon)
                        .font(.system(size: 15))
                        .foregroundColor(folder.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(folder.source)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(folder.fileCount) files")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(folder.activity)
                        .font(.system(size: 10))
                        .foregroundColor(Color(.tertiaryLabel))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Folder Card (pinned 2×2, no sensitivity badge)

private struct FolderCard: View {
    let folder: FolderItem

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(folder.accentColor)
                .frame(width: 3)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 13, bottomLeadingRadius: 13,
                    bottomTrailingRadius: 0, topTrailingRadius: 0
                ))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(folder.accentColor.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: folder.icon)
                            .font(.system(size: 18))
                            .foregroundColor(folder.accentColor)
                    }
                    Spacer()
                    if let dotColor = folder.statusDot.color {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(folder.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(folder.fileCount) files")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Recent File Row

private struct RecentFileRow: View {
    let file: SecureFile

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(file.fileTypeColor.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: file.fileTypeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(file.fileTypeColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(file.modifiedAt.relativeString)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Vault Folder Row

private struct VaultFolderRow: View {
    let folder: FolderItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(folder.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: folder.icon)
                    .font(.system(size: 16))
                    .foregroundColor(folder.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text("\(folder.fileCount) files · encrypted")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

// MARK: - Files stub

private struct FilesStubView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(Color(.tertiaryLabel))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AI Semantic Search Bar

private struct AISemanticSearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onSubmit: (() -> Void)? = nil

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: AppIcon.semanticSearch)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(brandBlue)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Search files with AI…")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                TextField("", text: $text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .focused(isFocused)
                    .submitLabel(.search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { onSubmit?() }
            }

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused.wrappedValue ? brandBlue.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { isFocused.wrappedValue = true }
        .animation(.easeInOut(duration: 0.15), value: isFocused.wrappedValue)
    }
}

// MARK: - Filter Chip

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

// MARK: - Files Tab Pill

private struct FilesTabPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? brandBlue : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting types (kept for compatibility)

struct WorkspaceItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let subtitle: String
    let activityDotColor: Color?

    static let samples: [WorkspaceItem] = [
        WorkspaceItem(name: "Acme Corp SharePoint", icon: "building.2.fill", color: .blue,
                      subtitle: "47 files · Last synced 2h ago", activityDotColor: .blue),
        WorkspaceItem(name: "XQ Secure Vault", icon: "lock.shield.fill",
                      color: Color(red: 0.686, green: 0.322, blue: 0.871),
                      subtitle: "7 encrypted files · AES-256-GCM", activityDotColor: nil),
        WorkspaceItem(name: "Local Vault", icon: "iphone.fill", color: .green,
                      subtitle: "12 offline files · On-device only", activityDotColor: nil),
    ]
}

struct AISuggestionItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    static let samples: [AISuggestionItem] = [
        AISuggestionItem(title: "3 files may need reclassification",
                         subtitle: "PHI detected · On-device scan · 95% confidence",
                         icon: "tag.fill",
                         color: Color(red: 0.686, green: 0.322, blue: 0.871)),
        AISuggestionItem(title: "Merge duplicate contracts",
                         subtitle: "MSA-Acme-v1 and MSA-Acme-Final are 94% identical",
                         icon: "doc.on.doc.fill",
                         color: .orange),
        AISuggestionItem(title: "14 archive candidates",
                         subtitle: "Files inactive for 90+ days",
                         icon: "archivebox.fill",
                         color: .gray),
    ]
}

private extension SensitivityLevel {
    var chipLabel: String {
        switch self {
        case .public_:      return "Public"
        case .internal_:    return "Internal"
        case .confidential: return "Confidential"
        case .restricted:   return "Restricted"
        }
    }
}

#Preview {
    FileBrowserView()
        .environmentObject(AppCoordinator())
}
