import SwiftUI
import XQCore

struct SharingCenterView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var showRevokeAlert = false
    @State private var revokeTarget: MockShare?
    @State private var showCreateShare = false
    @State private var selectedReceivedShare: ReceivedShare?
    @State private var selectedInvite: GroupInvite?

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    private var mockShares: [MockShare] { MockShare.samples }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsRow
                    receivedSharesSection
                    activeSharesList
                    activityFeedSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .navigationTitle("Sharing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            showCreateShare = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(brandBlue)
                        }
                        Button {
                            coordinator.presentProfile()
                        } label: {
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
            .sheet(isPresented: $showCreateShare) { CreateShareView() }
            .sheet(item: $selectedReceivedShare) { share in ReceivedShareView(share: share) }
            .sheet(item: $selectedInvite) { invite in GroupInviteView(invite: invite) }
            .alert("Revoke Share", isPresented: $showRevokeAlert, presenting: revokeTarget) { target in
                Button("Revoke", role: .destructive) { }
                Button("Cancel", role: .cancel) { }
            } message: { target in
                Text("Revoke access for \(target.recipientName)? They will no longer be able to open the file.")
            }
        }
    }

    // MARK: - Stats Row

    private var expiringSoonCount: Int {
        mockShares.filter { $0.expiresAt.timeIntervalSinceNow < 2 * 86400 && $0.expiresAt > Date() }.count
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            StatPill(value: "\(mockShares.count)", label: "Active", color: brandBlue)
            Divider().frame(height: 36)
            StatPill(value: "\(expiringSoonCount)", label: "Expiring", color: .orange)
            Divider().frame(height: 36)
            StatPill(value: "47", label: "Views", color: Color(red: 0.204, green: 0.780, blue: 0.349))
        }
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Received Shares

    private var receivedSharesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Received Shares")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                Spacer()
                Text("\(ReceivedShare.samples.count) new")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(brandBlue)
            }
            VStack(spacing: 0) {
                ForEach(ReceivedShare.samples) { share in
                    Button {
                        selectedReceivedShare = share
                    } label: {
                        ReceivedShareRow(share: share)
                    }
                    .buttonStyle(.plain)
                    if share.id != ReceivedShare.samples.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Active Shares

    private var activeSharesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active Shares")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            VStack(spacing: 0) {
                ForEach(mockShares) { share in
                    ShareRow(share: share) {
                        revokeTarget = share
                        showRevokeAlert = true
                    }
                    if share.id != mockShares.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Activity Feed

    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Activity")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            VStack(spacing: 0) {
                ForEach(MockShareActivity.samples) { activity in
                    ActivityRow(activity: activity)
                    if activity.id != MockShareActivity.samples.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
    }
}

// MARK: - Supporting Views

private struct StatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ShareRow: View {
    let share: MockShare
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(sensitivityColor(share.sensitivity).opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(share.fileExt.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(sensitivityColor(share.sensitivity))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(share.fileName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(share.recipientName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(expiryLabel(share.expiresAt))
                        .font(.system(size: 11))
                }
                .foregroundColor(share.expiresAt < Date().addingTimeInterval(86400) ? .orange : .secondary)
            }

            Spacer()

            Button {
                onRevoke()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func sensitivityColor(_ s: SensitivityLevel) -> Color {
        switch s {
        case .public_:      return .green
        case .internal_:    return Color(red: 0.239, green: 0.353, blue: 0.996)
        case .confidential: return Color(red: 0.427, green: 0.298, blue: 0.000)
        case .restricted:   return Color(red: 0.482, green: 0.000, blue: 0.200)
        }
    }

    private func expiryLabel(_ date: Date) -> String {
        let delta = date.timeIntervalSinceNow
        if delta < 0 { return "Expired" }
        let days = Int(delta / 86400)
        if days == 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }
}

private struct ActivityRow: View {
    let activity: MockShareActivity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.system(size: 16))
                .foregroundColor(activity.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(activity.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(activity.timeAgo)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

private struct ReceivedShareRow: View {
    let share: ReceivedShare
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(brandBlue.opacity(0.1))
                    .frame(width: 44, height: 44)
                Text(share.fileExt.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(brandBlue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(share.fileName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("From \(share.senderName)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(share.expiryLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct CreateShareView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recipientEmail = ""
    @State private var expiryDays = 7
    @State private var permissions = "View only"
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipient") {
                    TextField("Email address", text: $recipientEmail)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                }
                Section("Permissions") {
                    Picker("Access", selection: $permissions) {
                        Text("View only").tag("View only")
                        Text("View & download").tag("View & download")
                        Text("Edit").tag("Edit")
                    }
                }
                Section("Expiry") {
                    Stepper("\(expiryDays) day\(expiryDays == 1 ? "" : "s")",
                            value: $expiryDays, in: 1...30)
                }
                Section {
                    Button { dismiss() } label: {
                        HStack {
                            Spacer()
                            Label("Create Encrypted Share", systemImage: "lock.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(recipientEmail.isEmpty ? .secondary : .white)
                            Spacer()
                        }
                    }
                    .disabled(recipientEmail.isEmpty)
                    .listRowBackground(recipientEmail.isEmpty ? Color(.systemGray5) : brandBlue)
                }
            }
            .navigationTitle("New Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Mock Models

struct MockShare: Identifiable {
    let id = UUID()
    let fileName: String
    let fileExt: String
    let recipientName: String
    let expiresAt: Date
    let sensitivity: SensitivityLevel

    static let samples: [MockShare] = [
        MockShare(fileName: "Q4-Financial-Report.xlsx", fileExt: "xlsx",
                  recipientName: "Sarah Chen",
                  expiresAt: Date().addingTimeInterval(4 * 86400),
                  sensitivity: .confidential),
        MockShare(fileName: "Patient-Records-2025.pdf", fileExt: "pdf",
                  recipientName: "Dr. Michael Torres",
                  expiresAt: Date().addingTimeInterval(1 * 86400),
                  sensitivity: .restricted),
        MockShare(fileName: "Vendor-Contract-Draft.docx", fileExt: "docx",
                  recipientName: "Legal Team",
                  expiresAt: Date().addingTimeInterval(12 * 86400),
                  sensitivity: .internal_),
        MockShare(fileName: "Product-Roadmap-2026.pptx", fileExt: "pptx",
                  recipientName: "Board Members",
                  expiresAt: Date().addingTimeInterval(2 * 86400),
                  sensitivity: .confidential),
        MockShare(fileName: "Security-Audit-Report.pdf", fileExt: "pdf",
                  recipientName: "Compliance Team",
                  expiresAt: Date().addingTimeInterval(6 * 86400),
                  sensitivity: .restricted),
    ]
}

struct MockShareActivity: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let timeAgo: String

    static let samples: [MockShareActivity] = [
        MockShareActivity(icon: "eye.fill", color: .blue,
                          title: "File Viewed",
                          subtitle: "Sarah Chen opened Q4-Financial-Report.xlsx",
                          timeAgo: "2m ago"),
        MockShareActivity(icon: "arrow.up.forward.circle.fill",
                          color: Color(red: 0.239, green: 0.353, blue: 0.996),
                          title: "Share Created",
                          subtitle: "Patient-Records-2025.pdf shared with Dr. Torres",
                          timeAgo: "1h ago"),
        MockShareActivity(icon: "xmark.circle.fill", color: .orange,
                          title: "Share Revoked",
                          subtitle: "Board-Strategy.pdf link revoked early",
                          timeAgo: "3h ago"),
        MockShareActivity(icon: "exclamationmark.triangle.fill", color: .red,
                          title: "Policy Block",
                          subtitle: "External share blocked — restricted content",
                          timeAgo: "5h ago"),
        MockShareActivity(icon: "checkmark.shield.fill", color: .green,
                          title: "Encryption Verified",
                          subtitle: "Vendor-Contract-Draft.docx key verified",
                          timeAgo: "1d ago"),
    ]
}

#Preview {
    SharingCenterView()
        .environmentObject(AppCoordinator())
}
