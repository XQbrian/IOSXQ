import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var notifications = AppNotification.samples
    @State private var selectedFilter: NotifCategory? = nil

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    private var filtered: [AppNotification] {
        guard let cat = selectedFilter else { return notifications }
        return notifications.filter { $0.category == cat }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if filtered.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mark All Read") {
                        notifications = notifications.map {
                            AppNotification(id: $0.id, icon: $0.icon, color: $0.color,
                                            title: $0.title, body: $0.body, timeAgo: $0.timeAgo,
                                            category: $0.category, isRead: true)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(brandBlue)
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(label: "All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                ForEach(NotifCategory.allCases, id: \.self) { cat in
                    FilterPill(label: cat.label, isSelected: selectedFilter == cat) {
                        selectedFilter = selectedFilter == cat ? nil : cat
                    }
                }
            }
        }
    }

    // MARK: - List

    private var notificationList: some View {
        List {
            ForEach(filtered) { notif in
                NotificationRow(notif: notif) {
                    handleTap(notif)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparatorTint(Color(.systemGray5))
            }
        }
        .listStyle(.plain)
    }

    private func handleTap(_ notif: AppNotification) {
        markRead(notif)
        guard let tab = notif.destinationTab else { return }
        dismiss()
        coordinator.selectedTab = tab
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundColor(Color(.tertiaryLabel))
            Text("No notifications")
                .font(.system(size: 16, weight: .semibold))
            Text("You're all caught up.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func markRead(_ notif: AppNotification) {
        if let idx = notifications.firstIndex(where: { $0.id == notif.id }) {
            notifications[idx] = AppNotification(
                id: notif.id, icon: notif.icon, color: notif.color,
                title: notif.title, body: notif.body, timeAgo: notif.timeAgo,
                category: notif.category, isRead: true
            )
        }
    }
}

// MARK: - Sub-views

private struct FilterPill: View {
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

private struct NotificationRow: View {
    let notif: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(notif.color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: notif.icon)
                        .font(.system(size: 16))
                        .foregroundColor(notif.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notif.title)
                            .font(.system(size: 14, weight: notif.isRead ? .regular : .semibold))
                            .foregroundColor(notif.isRead ? .secondary : .primary)
                        Spacer()
                        Text(notif.timeAgo)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Text(notif.body)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !notif.isRead {
                    Circle()
                        .fill(Color(red: 0.239, green: 0.353, blue: 0.996))
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model

enum NotifCategory: String, CaseIterable {
    case security = "Security"
    case sharing  = "Sharing"
    case email    = "Email"
    case system   = "System"

    var label: String { rawValue }
}

struct AppNotification: Identifiable {
    let id: UUID
    let icon: String
    let color: Color
    let title: String
    let body: String
    let timeAgo: String
    let category: NotifCategory
    let isRead: Bool

    var destinationTab: AppCoordinator.AppTab? {
        switch category {
        case .security:
            return title.lowercased().contains("phishing") ? .email : .files
        case .sharing:
            return .sharing
        case .email:
            return .email
        case .system:
            return nil
        }
    }

    static let samples: [AppNotification] = [
        AppNotification(id: UUID(), icon: "exclamationmark.triangle.fill", color: .red,
                        title: "Phishing Detected",
                        body: "High-risk email from unknown sender flagged in your inbox.",
                        timeAgo: "5m ago", category: .security, isRead: false),
        AppNotification(id: UUID(),
                        icon: "arrow.up.forward.circle.fill",
                        color: Color(red: 0.239, green: 0.353, blue: 0.996),
                        title: "Share Expiring Soon",
                        body: "Patient-Records-2025.pdf link expires in 24 hours.",
                        timeAgo: "1h ago", category: .sharing, isRead: false),
        AppNotification(id: UUID(), icon: "eye.fill", color: .blue,
                        title: "File Accessed",
                        body: "Sarah Chen viewed Q4-Financial-Report.xlsx via your share link.",
                        timeAgo: "2h ago", category: .sharing, isRead: false),
        AppNotification(id: UUID(), icon: "lock.fill", color: .green,
                        title: "Encryption Complete",
                        body: "3 newly imported files have been encrypted and classified.",
                        timeAgo: "4h ago", category: .system, isRead: true),
        AppNotification(id: UUID(), icon: "envelope.badge.fill", color: .orange,
                        title: "Sensitive Email",
                        body: "Incoming message from legal@acme.com classified as Confidential.",
                        timeAgo: "6h ago", category: .email, isRead: true),
        AppNotification(id: UUID(), icon: "shield.slash.fill", color: .red,
                        title: "Policy Block",
                        body: "External share attempt for restricted file was blocked.",
                        timeAgo: "1d ago", category: .security, isRead: true),
        AppNotification(id: UUID(), icon: "tag.fill", color: .purple,
                        title: "Auto-Classification",
                        body: "2 files reclassified to Restricted based on new PHI scan.",
                        timeAgo: "2d ago", category: .system, isRead: true),
    ]
}
