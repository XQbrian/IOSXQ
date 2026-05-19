import SwiftUI
import XQCore

struct WorkspacesGroupsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var showCreateGroup = false
    @State private var selectedInvite: GroupInvite?

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    private var groups: [WorkspaceGroup] { WorkspaceGroup.samples }

    private var filtered: [WorkspaceGroup] {
        guard !searchQuery.isEmpty else { return groups }
        return groups.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                List {
                    Section {
                        ForEach(filtered) { group in
                            WorkspaceGroupRow(group: group)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    } header: {
                        Text("\(filtered.count) workspace\(filtered.count == 1 ? "" : "s")")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }

                    if !GroupInvite.pendingSamples.isEmpty {
                        Section {
                            ForEach(GroupInvite.pendingSamples) { invite in
                                PendingInviteRow(invite: invite) {
                                    selectedInvite = invite
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            }
                        } header: {
                            Text("Pending Invitations")
                                .font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("My Workspaces")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateGroup = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(brandBlue)
                    }
                }
            }
            .sheet(isPresented: $showCreateGroup) { CreateGroupView() }
            .sheet(item: $selectedInvite) { invite in GroupInviteView(invite: invite) }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14)).foregroundColor(.secondary)
            TextField("Search workspaces…", text: $searchQuery)
                .font(.system(size: 14)).autocorrectionDisabled()
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Workspace Group Row

private struct WorkspaceGroupRow: View {
    let group: WorkspaceGroup
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(group.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text(group.initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(group.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    if group.isOwner {
                        Text("OWNER")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(brandBlue)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(brandBlue.opacity(0.1)))
                    }
                }
                HStack(spacing: 10) {
                    Label("\(group.memberCount)", systemImage: "person.2")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                    Label("\(group.fileCount) files", systemImage: "doc")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Pending Invite Row

private struct PendingInviteRow: View {
    let invite: GroupInvite
    let onTap: () -> Void
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(invite.groupColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Text(invite.groupInitials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(invite.groupColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(invite.groupName)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Text("Invited by \(invite.inviterName)")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Text("View")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(brandBlue))
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Group

private struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var inviteEmails = ""
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    TextField("Workspace name", text: $groupName)
                    TextField("Invite members (emails, comma-separated)", text: $inviteEmails)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                }
                Section {
                    Button { dismiss() } label: {
                        HStack {
                            Spacer()
                            Text("Create Workspace")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(groupName.isEmpty ? .secondary : .white)
                            Spacer()
                        }
                    }
                    .disabled(groupName.isEmpty)
                    .listRowBackground(groupName.isEmpty ? Color(.systemGray5) : brandBlue)
                }
            }
            .navigationTitle("New Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Model

struct WorkspaceGroup: Identifiable {
    let id = UUID()
    let name: String
    let initials: String
    let color: Color
    let memberCount: Int
    let fileCount: Int
    let isOwner: Bool

    static let samples: [WorkspaceGroup] = [
        WorkspaceGroup(name: "Acme Corp Legal", initials: "AC",
                       color: Color(red: 0.239, green: 0.353, blue: 0.996),
                       memberCount: 8, fileCount: 34, isOwner: true),
        WorkspaceGroup(name: "Healthcare Division", initials: "HD",
                       color: Color(red: 0.482, green: 0.000, blue: 0.200),
                       memberCount: 12, fileCount: 89, isOwner: false),
        WorkspaceGroup(name: "Finance Team", initials: "FT",
                       color: Color(red: 0.204, green: 0.780, blue: 0.349),
                       memberCount: 5, fileCount: 21, isOwner: true),
        WorkspaceGroup(name: "Executive Board", initials: "EB",
                       color: Color(red: 0.427, green: 0.298, blue: 0.000),
                       memberCount: 6, fileCount: 15, isOwner: false),
        WorkspaceGroup(name: "Security & Compliance", initials: "SC",
                       color: .purple,
                       memberCount: 4, fileCount: 42, isOwner: true),
    ]
}

extension GroupInvite {
    static let pendingSamples: [GroupInvite] = [sample]
}

#Preview {
    WorkspacesGroupsView()
        .environmentObject(AppCoordinator())
}
