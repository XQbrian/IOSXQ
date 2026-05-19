import SwiftUI
import XQCore

struct GroupInviteView: View {
    @Environment(\.dismiss) private var dismiss
    let invite: GroupInvite

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    @State private var showDeclineAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    inviterCard
                    groupDetailsCard
                    membersPreview
                    actionButtons
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Workspace Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Decline Invitation", isPresented: $showDeclineAlert) {
                Button("Decline", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Decline the invitation to \(invite.groupName)?")
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(invite.groupColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                Text(invite.groupInitials)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(invite.groupColor)
            }
            Text(invite.groupName).font(.system(size: 20, weight: .bold))
            Text("You've been invited to join this workspace")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Inviter

    private var inviterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Invited By")
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(brandBlue).frame(width: 44, height: 44)
                    Text(invite.inviterInitials)
                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(invite.inviterName).font(.system(size: 15, weight: .semibold))
                    Text(invite.inviterEmail).font(.system(size: 13)).foregroundColor(.secondary)
                    Text("WORKSPACE ADMIN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(brandBlue)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(brandBlue.opacity(0.1)))
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Group Details

    private var groupDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Workspace Details")
            VStack(spacing: 10) {
                InviteDetailRow(icon: "person.2.fill", label: "Members",    value: "\(invite.memberCount)")
                InviteDetailRow(icon: "doc.fill",      label: "Files",      value: "\(invite.fileCount)")
                InviteDetailRow(icon: "lock.fill",     label: "Encryption", value: "AES-256-GCM",  iconColor: .green)
                InviteDetailRow(icon: "shield.fill",   label: "Policy",     value: invite.policy,  iconColor: brandBlue)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Members Preview

    private var membersPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Members")
            HStack(spacing: -10) {
                ForEach(invite.memberPreviews.prefix(5), id: \.self) { initials in
                    ZStack {
                        Circle()
                            .fill(invite.groupColor)
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        Text(initials)
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    }
                }
                if invite.memberCount > 5 {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        Text("+\(invite.memberCount - 5)")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button { dismiss() } label: {
                Label("Accept & Join Workspace", systemImage: "person.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(brandBlue))
            }
            Button { showDeclineAlert = true } label: {
                Text("Decline Invitation")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemBackground))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1))
                    )
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
    }
}

// MARK: - Detail Row

private struct InviteDetailRow: View {
    let icon: String
    let label: String
    let value: String
    var iconColor: Color = .secondary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(iconColor)
                .frame(width: 20)
            Text(label).font(.system(size: 14)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium))
        }
    }
}

// MARK: - Model

struct GroupInvite: Identifiable {
    let id = UUID()
    let groupName: String
    let groupInitials: String
    let groupColor: Color
    let inviterName: String
    let inviterEmail: String
    let memberCount: Int
    let fileCount: Int
    let policy: String
    let memberPreviews: [String]

    var inviterInitials: String {
        inviterName.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    static let sample = GroupInvite(
        groupName: "Healthcare Division",
        groupInitials: "HD",
        groupColor: Color(red: 0.482, green: 0.000, blue: 0.200),
        inviterName: "Sarah Chen",
        inviterEmail: "sarah.chen@acmecorp.com",
        memberCount: 12,
        fileCount: 89,
        policy: "Restricted content enabled",
        memberPreviews: ["SC", "MT", "JL", "AK", "BR", "NW", "PD"]
    )
}

#Preview {
    GroupInviteView(invite: .sample)
}
