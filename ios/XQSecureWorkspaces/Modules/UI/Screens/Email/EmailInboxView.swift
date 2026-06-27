import SwiftUI
import XQCore
import XQEmailIntelligence
import XQPolicy

struct EmailInboxView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm: EmailInboxViewModel
    @State private var showCompose = false
    @State private var showAISearch = false
    @State private var showNotifications = false

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    init() {
        let provider = LocalEmailIntelligenceProvider()
        let store = LocalSenderProfileStore()
        let orchestrator = EmailIntelligenceOrchestrator(
            prioritizer: provider,
            threadProvider: provider,
            toneAnalyzer: provider,
            riskDetector: provider,
            profileStore: store
        )
        _vm = StateObject(wrappedValue: EmailInboxViewModel(orchestrator: orchestrator))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))

                if let summary = vm.inboxSummary {
                    summaryBar(summary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                // Ask AI bar — mirrors Files screen
                Button { showAISearch = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles.magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(brandBlue)
                        Text("Ask AI: find emails with PHI attachments…")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("✦ AI")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(brandBlue))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                if vm.isLoading {
                    Spacer()
                    ProgressView("Loading inbox…")
                    Spacer()
                } else if vm.displayedEmails.isEmpty {
                    emptyState
                } else {
                    emailList
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        Button { showNotifications = true } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(.primary)
                                Circle()
                                    .fill(Color(red: 1, green: 0.231, blue: 0.188))
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                        Button { showCompose = true } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 17))
                                .foregroundColor(brandBlue)
                        }
                        Button { coordinator.presentProfile() } label: {
                            ZStack {
                                Circle().fill(brandBlue).frame(width: 28, height: 28)
                                Text("BW")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCompose) { EmailComposeView() }
            .sheet(isPresented: $showAISearch) {
                SemanticSearchView()
                    .environmentObject(coordinator)
            }
            .sheet(isPresented: $showNotifications) {
                NavigationStack { NotificationCenterView() }
            }
        }
        .task {
            guard let session = coordinator.currentSession else { return }
            let graphClient = coordinator.graphToken.map { MicrosoftGraphClient(graphToken: $0) }
            await vm.loadInbox(session: session, graphClient: graphClient)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EmailInboxViewModel.Filter.allCases, id: \.self) { filter in
                    FilterChip(
                        label: filter.rawValue,
                        isSelected: vm.selectedFilter == filter,
                        brandBlue: brandBlue
                    ) {
                        vm.selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Summary Bar

    @ViewBuilder
    private func summaryBar(_ s: EmailInboxViewModel.InboxSummary) -> some View {
        HStack(spacing: 0) {
            SummaryChip(count: s.criticalCount, label: "Critical", color: .red)
            SummaryChip(count: s.actionCount,   label: "Action",   color: .orange)
            SummaryChip(count: s.fyiCount,      label: "FYI",      color: brandBlue)
            SummaryChip(count: s.noiseCount,    label: "Noise",    color: .secondary)
        }
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Email List

    private var emailList: some View {
        List {
            ForEach(vm.displayedEmails) { email in
                NavigationLink(destination: EmailDetailView(email: email)) {
                    EmailRow(
                        email: email,
                        triage: vm.triageResults[email.id],
                        brandBlue: brandBlue
                    )
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .onAppear {
                    if !email.isRead { vm.markRead(email.id) }
                }
            }
        }
        .listStyle(.plain)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Inbox is empty")
                .font(.system(size: 17, weight: .semibold))
            Text("No messages to display.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Helpers

    private var titleText: String {
        let unread = vm.unreadCount
        return unread > 0 ? "Inbox (\(unread))" : "Inbox"
    }

    private func defaultPolicy() -> PolicyBundle {
        PolicyBundle(
            version: "1.0",
            signatureHex: String(repeating: "a", count: 64),
            rules: SensitivityLevel.allCases.map { level in
                PolicyRule(id: UUID(), name: "\(level.rawValue) Policy", sensitivity: level,
                           allowExternalShare: level == .public_ || level == .internal_,
                           maxShareExpiryDays: level == .restricted ? nil : 30,
                           requireApprovalFromRole: level == .restricted ? "admin" : nil,
                           cloudAIPermitted: level == .public_)
            },
            fetchedAt: Date()
        )
    }
}

// MARK: - Email Row

private struct EmailRow: View {
    let email: SecureEmail
    let triage: EmailTriageResult?
    let brandBlue: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(email.isRead ? Color.clear : brandBlue)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            Circle()
                .fill(avatarColor.opacity(0.18))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(email.senderName.prefix(1).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(avatarColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(email.senderName)
                        .font(.system(size: 14, weight: email.isRead ? .regular : .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(relativeDate(email.receivedAt))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Text(email.subject)
                    .font(.system(size: 13, weight: email.isRead ? .regular : .medium))
                    .foregroundColor(email.isRead ? .secondary : .primary)
                    .lineLimit(1)

                Text(email.bodyPreview)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    SensitivityBadge(sensitivity: email.sensitivity)
                    if let triage { PriorityBadge(priority: triage.priority) }
                    if email.hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var avatarColor: Color {
        let colors: [Color] = [brandBlue, .green, .orange, .purple, .pink]
        return colors[abs(email.senderEmail.hashValue) % colors.count]
    }

    private func relativeDate(_ date: Date) -> String {
        let delta = Date().timeIntervalSince(date)
        if delta < 3600 { return "\(Int(delta / 60))m" }
        if delta < 86400 { return "\(Int(delta / 3600))h" }
        let df = DateFormatter(); df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}

// MARK: - Priority Badge

private struct PriorityBadge: View {
    let priority: EmailPriority

    var body: some View {
        Text(priority.label)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(priorityColor.opacity(0.12))
            .foregroundColor(priorityColor)
            .clipShape(Capsule())
    }

    private var priorityColor: Color {
        switch priority {
        case .critical: return .red
        case .action:   return .orange
        case .fyi:      return .blue
        case .noise:    return .secondary
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let brandBlue: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(isSelected ? brandBlue : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary Chip

private struct SummaryChip: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(count > 0 ? color : .secondary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
