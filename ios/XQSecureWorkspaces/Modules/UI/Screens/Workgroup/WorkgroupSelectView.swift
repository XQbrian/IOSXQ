import SwiftUI

struct WorkgroupSelectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var workgroups = Workgroup.samples
    @State private var activeId: UUID? = Workgroup.samples.first(where: { $0.isActive })?.id

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    private var filtered: [Workgroup] {
        guard !searchText.isEmpty else { return workgroups }
        return workgroups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                List {
                    if filtered.isEmpty {
                        Text("No workgroups found")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(filtered) { wg in
                            WorkgroupRow(workgroup: wg, isActive: wg.id == activeId) {
                                activeId = wg.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    dismiss()
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Workgroup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(brandBlue)
                    }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            TextField("Search workgroups…", text: $searchText)
                .font(.system(size: 15))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Row

private struct WorkgroupRow: View {
    let workgroup: Workgroup
    let isActive: Bool
    let onSelect: () -> Void

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isActive ? brandBlue : brandBlue.opacity(0.1))
                        .frame(width: 46, height: 46)
                    Text(workgroup.initials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isActive ? .white : brandBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(workgroup.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    HStack(spacing: 8) {
                        Label("\(workgroup.memberCount)", systemImage: "person.2")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Label("\(workgroup.fileCount) files", systemImage: "folder")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(brandBlue)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model

struct Workgroup: Identifiable {
    let id: UUID
    let name: String
    let memberCount: Int
    let fileCount: Int
    let isActive: Bool

    var initials: String {
        name.components(separatedBy: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0) } }
            .joined()
            .uppercased()
    }

    static let samples: [Workgroup] = [
        Workgroup(id: UUID(), name: "XQ HQ — Engineering", memberCount: 24, fileCount: 312, isActive: true),
        Workgroup(id: UUID(), name: "Legal & Compliance", memberCount: 8, fileCount: 156, isActive: false),
        Workgroup(id: UUID(), name: "Finance Team", memberCount: 12, fileCount: 89, isActive: false),
        Workgroup(id: UUID(), name: "Product & Design", memberCount: 16, fileCount: 204, isActive: false),
        Workgroup(id: UUID(), name: "Executive Suite", memberCount: 5, fileCount: 43, isActive: false),
        Workgroup(id: UUID(), name: "Sales Operations", memberCount: 31, fileCount: 178, isActive: false),
    ]
}
