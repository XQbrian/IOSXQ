import SwiftUI
import XQCore

// MARK: - Folder View

struct FolderView: View {
    let folder: FolderItem
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var files = SampleDataRepository.sampleFiles
    @State private var isSelectMode = false
    @State private var selectedFileIDs: Set<UUID> = []
    @State private var showAITip = true
    @State private var showInsights = false
    @State private var showAIOrganize = false
    @State private var navigationPath = NavigationPath()
    /// Drives programmatic push of FileViewerView onto the enclosing
    /// NavigationStack (FileBrowserView's). Replaces the old
    /// `coordinator.route = .fileViewer(file)` root-replacement.
    @State private var pendingPushFile: SecureFile?

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let aiPurple = Color(red: 0.686, green: 0.322, blue: 0.871)

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                subfolderChips
                Divider()

                ScrollView {
                    VStack(spacing: 0) {
                        if showAITip {
                            aiTipStrip
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                        }
                        fileList
                    }
                    .padding(.bottom, isSelectMode ? 100 : 32)
                }
            }

            if isSelectMode {
                batchActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Button {
                        showInsights = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 17))
                            .foregroundColor(brandBlue)
                    }

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            if isSelectMode {
                                isSelectMode = false
                                selectedFileIDs = []
                            } else {
                                isSelectMode = true
                            }
                        }
                    } label: {
                        Text(isSelectMode ? "Done" : "Select")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(brandBlue)
                    }
                }
            }
        }
        .navigationDestination(for: SecureFile.self) { file in
            FileViewerView(file: file)
        }
        // Programmatic-push fallback for callers that use a tap closure
        // instead of a NavigationLink(value:). Setting `pendingPushFile = file`
        // pushes FileViewerView onto the enclosing NavigationStack with a
        // standard system back button.
        .navigationDestination(item: $pendingPushFile) { file in
            FileViewerView(file: file)
        }
        .sheet(isPresented: $showInsights) {
            FolderInsightsSheet(folder: folder)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAIOrganize) {
            AIOrganizeView(folderName: folder.name)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Subfolder chips

    private var subfolderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(folder.subfolders, id: \.self) { sub in
                    HStack(spacing: 5) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundColor(brandBlue)
                        Text(sub)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                            .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 0.5))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - AI tip strip

    private var aiTipStrip: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(aiPurple.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(aiPurple)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("AI Suggestion")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(aiPurple)
                Text("3 files can be auto-classified. On-device analysis.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                showAIOrganize = true
            } label: {
                Text("Review")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(aiPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(aiPurple.opacity(0.12))
                            .overlay(Capsule().stroke(aiPurple.opacity(0.3), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { showAITip = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [aiPurple.opacity(0.09), brandBlue.opacity(0.06)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(aiPurple.opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    // MARK: - File list

    private var fileList: some View {
        VStack(spacing: 0) {
            ForEach(files) { file in
                FolderFileRow(
                    file: file,
                    isSelectMode: isSelectMode,
                    isSelected: selectedFileIDs.contains(file.id)
                ) {
                    if isSelectMode {
                        if selectedFileIDs.contains(file.id) {
                            selectedFileIDs.remove(file.id)
                        } else {
                            selectedFileIDs.insert(file.id)
                        }
                    } else {
                        // Push onto the enclosing NavigationStack so the user
                        // gets a system back button. `.navigationDestination(
                        // item: $pendingPushFile)` below handles the actual push.
                        pendingPushFile = file
                    }
                }

                if file.id != files.last?.id {
                    Divider().padding(.leading, isSelectMode ? 72 : 56)
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Batch action bar

    private var batchActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Text(selectedFileIDs.isEmpty ? "Select items" : "\(selectedFileIDs.count) selected")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 70)
                    .padding(.leading, 8)

                Spacer()

                batchButton(icon: "folder.badge.plus", label: "Move") {}
                batchButton(icon: "square.and.arrow.up", label: "Share") {}
                batchButton(icon: "tag", label: "Classify") { showAIOrganize = true }
                batchButton(icon: "trash", label: "Delete", color: .red) {}
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .padding(.bottom, 24)
        }
        .background(.regularMaterial)
    }

    private func batchButton(icon: String, label: String, color: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(selectedFileIDs.isEmpty ? .secondary : color)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(selectedFileIDs.isEmpty ? .secondary : color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(selectedFileIDs.isEmpty)
    }
}

// MARK: - Folder File Row

private struct FolderFileRow: View {
    let file: SecureFile
    let isSelectMode: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isSelectMode {
                    ZStack {
                        Circle()
                            .fill(isSelected
                                  ? Color(red: 0.239, green: 0.353, blue: 0.996)
                                  : Color(.systemGray5))
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .animation(.spring(response: 0.25), value: isSelected)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(file.fileTypeColor.opacity(0.12))
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

                    HStack(spacing: 6) {
                        SensitivityMicroBadge(sensitivity: file.sensitivity)
                        Text(file.modifiedAt.relativeString)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
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
        .buttonStyle(.plain)
    }
}

private struct SensitivityMicroBadge: View {
    let sensitivity: SensitivityLevel

    var body: some View {
        Text(sensitivity.microLabel)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(sensitivity.microColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(sensitivity.microColor.opacity(0.12))
            )
    }
}

// MARK: - Folder Insights Sheet

private struct FolderInsightsSheet: View {
    let folder: FolderItem

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Health score
                    VStack(spacing: 6) {
                        Text("Folder Health")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("72")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.orange)
                        ProgressView(value: 0.72)
                            .tint(.orange)
                            .padding(.horizontal, 32)
                        Text("3 items need attention")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Classification breakdown
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Classification Breakdown")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        ForEach([
                            ("Restricted", 2, Color.red),
                            ("Confidential", 8, Color.orange),
                            ("Internal", 24, Color.blue),
                            ("Public", 5, Color.green),
                        ], id: \.0) { label, count, color in
                            HStack {
                                Circle().fill(color).frame(width: 8, height: 8)
                                Text(label).font(.system(size: 13))
                                Spacer()
                                Text("\(count) files")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Security posture
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Security Posture")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        ForEach([
                            ("Encrypted at rest", true),
                            ("All files classified", false),
                            ("No overdue shares", true),
                            ("MFA enforced", true),
                        ], id: \.0) { label, ok in
                            HStack {
                                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(ok ? .green : .orange)
                                Text(label).font(.system(size: 13))
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
            .navigationTitle("Folder Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - FolderItem model

struct FolderItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let accentColor: Color
    let sensitivity: SensitivityLevel
    let fileCount: Int
    let subfolders: [String]
    let statusDot: FolderStatusDot

    enum FolderStatusDot {
        case none, newContent, updated, critical, aiVault, stale

        var color: Color? {
            switch self {
            case .none:       return nil
            case .newContent: return .blue
            case .updated:    return .orange
            case .critical:   return .red
            case .aiVault:    return Color(red: 0.686, green: 0.322, blue: 0.871)
            case .stale:      return .gray
            }
        }
    }

    static let pinned: [FolderItem] = [
        FolderItem(name: "Finance & Legal", icon: "dollarsign.square.fill",
                   accentColor: .orange, sensitivity: .confidential, fileCount: 39,
                   subfolders: ["NDAs", "Reports", "Contracts", "Archive"],
                   statusDot: .updated),
        FolderItem(name: "Legal & Compliance", icon: "building.columns.fill",
                   accentColor: .red, sensitivity: .restricted, fileCount: 14,
                   subfolders: ["HIPAA", "SOC2", "Contracts"],
                   statusDot: .critical),
        FolderItem(name: "XQ Secure Vault", icon: "lock.shield.fill",
                   accentColor: Color(red: 0.686, green: 0.322, blue: 0.871),
                   sensitivity: .restricted, fileCount: 7,
                   subfolders: ["Keys", "Certs"],
                   statusDot: .aiVault),
        FolderItem(name: "Shared with Me", icon: "person.2.fill",
                   accentColor: .blue, sensitivity: .internal_, fileCount: 22,
                   subfolders: ["From Team", "External"],
                   statusDot: .newContent),
    ]
}

// MARK: - Supporting extensions

extension SecureFile {
    var fileTypeIcon: String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":             return "doc.richtext.fill"
        case "xlsx", "xls", "csv": return "tablecells.fill"
        case "docx", "doc":    return "doc.text.fill"
        case "pptx", "ppt":    return "rectangle.on.rectangle.fill"
        case "png", "jpg", "jpeg", "heic": return "photo.fill"
        case "mp4", "mov":     return "play.rectangle.fill"
        default:               return "doc.fill"
        }
    }

    var fileTypeColor: Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":             return .red
        case "xlsx", "xls", "csv": return .green
        case "docx", "doc":    return .blue
        case "pptx", "ppt":    return .orange
        case "png", "jpg", "jpeg", "heic": return .purple
        case "mp4", "mov":     return .pink
        default:               return .secondary
        }
    }
}

extension Date {
    var relativeString: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        let days = Int(interval / 86400)
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: self)
    }
}

extension SensitivityLevel {
    var microLabel: String {
        switch self {
        case .public_:      return "PUB"
        case .internal_:    return "INT"
        case .confidential: return "CON"
        case .restricted:   return "RES"
        }
    }

    var microColor: Color {
        switch self {
        case .public_:      return Color(red: 0.204, green: 0.780, blue: 0.349)
        case .internal_:    return Color(red: 0.239, green: 0.353, blue: 0.996)
        case .confidential: return Color(red: 1.000, green: 0.584, blue: 0.000)
        case .restricted:   return Color(red: 1.000, green: 0.231, blue: 0.188)
        }
    }
}
