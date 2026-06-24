import SwiftUI

// MARK: - AI Organize View

struct AIOrganizeView: View {
    let folderName: String
    @Environment(\.dismiss) private var dismiss

    @State private var actions: [AIOrganizeAction] = AIOrganizeAction.samples
    @State private var showUndoBanner = false

    private let aiPurple = Color(red: 0.686, green: 0.322, blue: 0.871)
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    private var pendingActions: [AIOrganizeAction] {
        actions.filter { $0.state == .pending }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryStrip

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($actions) { $action in
                            if action.state != .skipped {
                                AIOrganizeCard(action: $action, aiPurple: aiPurple) {
                                    applyAction(&action)
                                } onSkip: {
                                    withAnimation { action.state = .skipped }
                                }
                            }
                        }

                        if pendingActions.isEmpty {
                            completedState.padding(.top, 32)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("AI Organization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !pendingActions.isEmpty {
                        Button {
                            withAnimation {
                                for idx in actions.indices where actions[idx].state == .pending {
                                    actions[idx].state = .applied
                                }
                            }
                            flashUndo()
                        } label: {
                            Text("Apply All")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(brandBlue))
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showUndoBanner {
                    undoBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                }
            }
        }
    }

    // MARK: - Summary strip

    private var summaryStrip: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(aiPurple.opacity(0.18))
                    .frame(width: 36, height: 36)
                Text("✦")
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(max(pendingActions.count, 0)) changes planned")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text("On-device analysis only · No cloud upload · Review each")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(pendingActions.count)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(aiPurple)
                Text("pending")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            LinearGradient(
                colors: [aiPurple.opacity(0.09), brandBlue.opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Completed state

    private var completedState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
            }
            Text("All done!")
                .font(.system(size: 18, weight: .bold))
            Text("Your folder has been organized.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Button("Close") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Capsule().fill(brandBlue))
                .padding(.top, 8)
        }
    }

    // MARK: - Undo banner

    private var undoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            Text("Changes applied")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button("Undo") {
                withAnimation {
                    for idx in actions.indices where actions[idx].state == .applied {
                        actions[idx].state = .pending
                    }
                    showUndoBanner = false
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(brandBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        )
    }

    // MARK: - Helpers

    private func applyAction(_ action: inout AIOrganizeAction) {
        action.state = .applied
        flashUndo()
    }

    private func flashUndo() {
        showUndoBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showUndoBanner = false }
        }
    }
}

// MARK: - AI Organize Card

private struct AIOrganizeCard: View {
    @Binding var action: AIOrganizeAction
    let aiPurple: Color
    let onApply: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(action.accentColor.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: action.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(action.accentColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(action.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(action.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if action.state == .applied {
                    Text("✓ Applied")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Confidence bar
            HStack(spacing: 8) {
                Text("Confidence")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5)).frame(height: 4)
                        Capsule()
                            .fill(action.accentColor)
                            .frame(width: geo.size.width * action.confidence, height: 4)
                    }
                }
                .frame(height: 4)
                Text("\(Int(action.confidence * 100))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(action.accentColor)
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // File list preview
            VStack(spacing: 0) {
                ForEach(action.files.prefix(3), id: \.self) { fileName in
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(fileName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        if let dest = action.destination {
                            Image(systemName: "arrow.right").font(.system(size: 9)).foregroundColor(.secondary)
                            Text(dest).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    if fileName != action.files.prefix(3).last {
                        Divider().padding(.leading, 34)
                    }
                }
                if action.files.count > 3 {
                    Text("+ \(action.files.count - 3) more")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
            }
            .background(Color(.systemBackground).opacity(0.6))

            if action.state == .pending {
                Divider()
                HStack(spacing: 10) {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Color(.systemGray6)))
                    }
                    .buttonStyle(.plain)

                    Button(action: onApply) {
                        Text("Apply ✓")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(action.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 9).fill(action.accentColor.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(action.accentColor.opacity(0.3), lineWidth: 1)
        )
        .opacity(action.state == .applied ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: action.state)
    }
}

// MARK: - Model

struct AIOrganizeAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let confidence: Double
    let accentColor: Color
    let files: [String]
    let destination: String?
    var state: ActionState = .pending

    enum ActionState { case pending, applied, skipped }

    static let samples: [AIOrganizeAction] = [
        AIOrganizeAction(
            title: "Auto-classify 3 files",
            subtitle: "Detected PHI — recommend Restricted",
            icon: "tag.fill", confidence: 0.95,
            accentColor: Color(red: 0.686, green: 0.322, blue: 0.871),
            files: ["Patient-Records-Oct.pdf", "Insurance-Claims.xlsx", "Medical-Summary.docx"],
            destination: "Restricted"
        ),
        AIOrganizeAction(
            title: "Merge duplicate contracts",
            subtitle: "2 nearly identical files detected",
            icon: "arrow.triangle.merge", confidence: 0.87,
            accentColor: .orange,
            files: ["MSA-Acme-v1.pdf", "MSA-Acme-Final.pdf"],
            destination: nil
        ),
        AIOrganizeAction(
            title: "Archive 14 stale files",
            subtitle: "Not accessed in 90+ days",
            icon: "archivebox.fill", confidence: 0.71,
            accentColor: .gray,
            files: ["Q1-2024-Report.xlsx", "Old-NDA-Template.docx", "Archive-Notes.txt"],
            destination: "Archive"
        ),
        AIOrganizeAction(
            title: "Create \"Acme Corp\" subfolder",
            subtitle: "7 files share this client prefix",
            icon: "folder.badge.plus", confidence: 0.82,
            accentColor: Color(red: 0.239, green: 0.353, blue: 0.996),
            files: ["Acme-Contract.pdf", "Acme-Invoice-Q3.xlsx", "Acme-SLA.docx"],
            destination: "Acme Corp/"
        ),
    ]
}
