import SwiftUI
import XQCore
import XQRepository
import XQFileIntelligence

struct FileBrowserView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = FileBrowserViewModel()

    @State private var navigationPath = NavigationPath()
    @FocusState private var searchFocused: Bool

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                headerStack

                if vm.isLoading && vm.files.isEmpty {
                    skeletonList
                } else {
                    contentList
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
            .navigationDestination(for: SecureFile.self) { file in
                FileViewerView(file: file)
            }
            .task {
                if let repo = coordinator.repository {
                    vm.configure(repository: repo)
                }
                await vm.load(path: "/")
            }
        }
    }

    // MARK: - Header stack (banner + AI search + chips)

    private var headerStack: some View {
        VStack(spacing: 0) {
            if vm.orgRiskScore > 0 {
                OrgRiskBanner(
                    riskScore: vm.orgRiskScore,
                    restrictedCount: vm.restrictedCount
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            AISemanticSearchBar(
                text: $vm.searchQuery,
                isFocused: $searchFocused
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

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
                .padding(.vertical, 6)
            }
            .background(Color(.systemBackground))

            Divider()
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Skeleton (loading) list

    private var skeletonList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonRow()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    // MARK: - Content list

    private var contentList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                section(
                    title: "SharePoint — Acme Corp",
                    files: vm.filteredFiles.filter { $0.sourceProvider == .sharePoint }
                )

                section(
                    title: "XQ Vault",
                    files: vm.filteredFiles.filter { $0.sourceProvider == .xqVault }
                )

                section(
                    title: "Local Vault",
                    files: vm.filteredFiles.filter { $0.sourceProvider == .localVault }
                )

                section(
                    title: "Other Sources",
                    files: vm.filteredFiles.filter {
                        $0.sourceProvider != .sharePoint &&
                        $0.sourceProvider != .localVault &&
                        $0.sourceProvider != .xqVault
                    }
                )

                if vm.filteredFiles.isEmpty && !vm.isLoading {
                    EmptyStateView()
                        .padding(.top, 48)
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
        .refreshable {
            await vm.refresh()
        }
    }

    @ViewBuilder
    private func section(title: String, files: [SecureFile]) -> some View {
        if !files.isEmpty {
            Section {
                VStack(spacing: 0) {
                    ForEach(files) { file in
                        NavigationLink(value: file) {
                            FileRowView(file: file)
                                .background(Color(.systemBackground))
                        }
                        .buttonStyle(.plain)

                        if file.id != files.last?.id {
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
                SectionHeader(title: title)
            }
        }
    }
}

// MARK: - Org Risk Banner

private struct OrgRiskBanner: View {
    let riskScore: Int
    let restrictedCount: Int

    private var severityColor: Color {
        if riskScore >= 75 {
            return Color(red: 0.853, green: 0.137, blue: 0.184) // red
        } else if riskScore >= 40 {
            return Color(red: 0.965, green: 0.561, blue: 0.078) // orange
        } else {
            return Color(red: 0.114, green: 0.667, blue: 0.357) // green
        }
    }

    private var severityIcon: String {
        if riskScore >= 75 {
            return "exclamationmark.octagon.fill"
        } else if riskScore >= 40 {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.shield.fill"
        }
    }

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                // Vertical gradient bar on the left
                LinearGradient(
                    colors: [severityColor, severityColor.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 4)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 10,
                        bottomLeadingRadius: 10,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

                Image(systemName: severityIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(severityColor)
                    .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Org Risk Score: \(riskScore)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("\(restrictedCount) RESTRICTED \(restrictedCount == 1 ? "file" : "files") · Tap to review")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 12)
            }
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(severityColor.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Semantic Search Bar

private struct AISemanticSearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.magnifyingglass")
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
            }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused.wrappedValue ? brandBlue.opacity(0.6) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused.wrappedValue = true
        }
        .animation(.easeInOut(duration: 0.15), value: isFocused.wrappedValue)
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 72, height: 72)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.secondary)
            }
            VStack(spacing: 4) {
                Text("No files match")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Try a different filter or AI search query.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Skeleton Row

private struct SkeletonRow: View {
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        HStack(spacing: 12) {
            shimmerBlock
                .frame(width: 40, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 8) {
                shimmerBlock
                    .frame(height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                shimmerBlock
                    .frame(width: 120, height: 9)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            Spacer()

            shimmerBlock
                .frame(width: 60, height: 18)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
    }

    private var shimmerBlock: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color(.systemFill))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.55),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: geo.size.width * shimmerOffset)
                )
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

#Preview {
    FileBrowserView()
        .environmentObject(AppCoordinator())
}
