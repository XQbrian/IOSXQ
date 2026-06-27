import SwiftUI

// MARK: - Notification Center (s-notification-center)
// Reached from Home's bell button. Shows Critical / Important / Informational alerts.

struct NotificationCenterView: View {
    @State private var dismissedIDs: Set<String> = []

    private let danger = Color(red: 1.000, green: 0.231, blue: 0.188)
    private let warn   = Color(red: 1.000, green: 0.584, blue: 0.000)
    private let ok     = Color(red: 0.204, green: 0.780, blue: 0.349)
    private let brand  = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Critical
                SectionHeader(label: "Critical", color: danger)
                    .padding(.top, 4)

                VStack(spacing: 7) {
                    if !dismissedIDs.contains("crit-1") {
                        AlertCard(
                            icon: "shield.exclamationmark.fill",
                            iconBg: danger.opacity(0.1),
                            iconColor: danger,
                            accent: danger,
                            title: "Policy violation detected",
                            body: "Outbound email attempted with unencrypted PHI attachment. Blocked by DLP.",
                            timestamp: "Just now · Requires acknowledgment",
                            actionLabel: "Review",
                            actionColor: danger
                        ) { dismissedIDs.insert("crit-1") }
                    }

                    if !dismissedIDs.contains("crit-2") {
                        AlertCard(
                            icon: "lock.fill",
                            iconBg: danger.opacity(0.1),
                            iconColor: danger,
                            accent: danger,
                            title: "Unauthorized access attempt",
                            body: "2 failed decryption attempts on Patient Records from unrecognized device.",
                            timestamp: "12 min ago · Pinned until acknowledged",
                            actionLabel: "Review",
                            actionColor: danger
                        ) { dismissedIDs.insert("crit-2") }
                    }
                }
                .padding(.bottom, 20)

                // MARK: Important
                SectionHeader(label: "Important", color: warn)

                VStack(spacing: 7) {
                    AlertCard(
                        icon: "arrow.down.doc.fill",
                        iconBg: warn.opacity(0.1),
                        iconColor: warn,
                        accent: warn,
                        title: "New secure document shared",
                        body: "Patient-Discharge-Summary.pdf from Carol Thomas",
                        timestamp: "2 hours ago · Expires in 7 days",
                        actionLabel: nil,
                        actionColor: .clear
                    ) {}

                    AlertCard(
                        icon: "person.badge.checkmark.fill",
                        iconBg: warn.opacity(0.1),
                        iconColor: warn,
                        accent: warn,
                        title: "Approval requested",
                        body: "Legal review needed before Q4-Financial-Report.pdf expires today.",
                        timestamp: "Today · Expires in 4 hours",
                        actionLabel: "Approve",
                        actionColor: brand
                    ) {}
                }
                .padding(.bottom, 20)

                // MARK: Informational
                SectionHeader(label: "Informational", color: .secondary)

                VStack(spacing: 0) {
                    InfoRow(icon: "checkmark.icloud.fill", iconColor: ok,
                            title: "Vault sync completed",
                            sub: "1,247 files verified · 8:45 AM")
                    Divider().padding(.leading, 50)
                    InfoRow(icon: "building.2.fill", iconColor: brand,
                            title: "Policy bundle updated",
                            sub: "v2.1.4 deployed · 8:15 AM")
                    Divider().padding(.leading, 50)
                    InfoRow(icon: "archivebox.fill", iconColor: .secondary,
                            title: "Backup completed",
                            sub: "Encrypted backup · Yesterday 11:00 PM")
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Sub-components

private struct SectionHeader: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .kerning(0.4)
            .padding(.vertical, 8)
    }
}

private struct AlertCard: View {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let accent: Color
    let title: String
    let body: String
    let timestamp: String
    let actionLabel: String?
    let actionColor: Color
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBg)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text(body)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                Text(timestamp)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 1)
            }

            Spacer()

            if let label = actionLabel {
                Button(action: onAction) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(actionColor))
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accent)
                .frame(width: 3)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 13, bottomLeadingRadius: 13,
                        bottomTrailingRadius: 0, topTrailingRadius: 0)
                )
        }
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

private struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let sub: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

#Preview {
    NavigationStack {
        NotificationCenterView()
    }
}
