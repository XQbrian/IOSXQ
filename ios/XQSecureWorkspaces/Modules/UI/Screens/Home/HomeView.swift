import SwiftUI
import XQCore

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = HomeViewModel(
        repository: StubRepositoryProvider(),
        policyEngine: StubPolicyEngine()
    )

    @State private var showAIImport = false
    @State private var selectedFile: SecureFile?

    private let brand    = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let brandAlt = Color(red: 0.412, green: 0.471, blue: 0.973)
    private let danger   = Color(red: 1.000, green: 0.231, blue: 0.188)
    private let warn     = Color(red: 1.000, green: 0.584, blue: 0.000)
    private let ok       = Color(red: 0.204, green: 0.780, blue: 0.349)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    aiCommandBar
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 10)

                    aiDailyBriefing
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                    priorityActionsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)

                    aiWorkspaceInsights
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                    quickAccess
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                    recentFiles
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    Spacer(minLength: 24)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        NavigationLink(destination: NotificationCenterView()) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                        }
                        Button {
                            coordinator.presentProfile()
                        } label: {
                            ZStack {
                                Circle().fill(brand).frame(width: 32, height: 32)
                                Text("BW")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .task {
                let repo: any RepositoryProvider = coordinator.localVaultProvider
                    ?? coordinator.repository
                    ?? StubRepositoryProvider()
                vm.configure(repository: repo, policyEngine: coordinator.policyEngine)
                await vm.loadDashboard()
            }
            .sheet(isPresented: $showAIImport) {
                AIImportView()
            }
            .sheet(item: $selectedFile) { file in
                NavigationStack { FileViewerView(file: file) }
            }
        }
    }

    // MARK: AI Command Bar

    private var aiCommandBar: some View {
        Button {
            coordinator.selectedTab = .files
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(LinearGradient(
                                colors: [brand, brandAlt],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Text("✦")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("XQ AI Assistant")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        Text("On-device · encrypted workspace intelligence")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("● Active")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ok)
                }

                HStack {
                    Text("Ask anything about your workspace…")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Ask")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(brand))
                }
                .padding(10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(["📁 Files at risk", "📋 Pending approvals",
                                 "🚫 Revoke shares", "🧹 Cleanup"], id: \.self) { chip in
                            Text(chip)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(brand)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(brand.opacity(0.1)))
                        }
                    }
                }
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [brand.opacity(0.08), brandAlt.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(brand.opacity(0.2), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: AI Daily Briefing

    private var aiDailyBriefing: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("🤖")
                    .font(.system(size: 11))
                Text("AI DAILY BRIEFING · 9:41 AM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .kerning(0.5)
            }
            .padding(.bottom, 10)

            Text("You have **3 sensitive files** shared externally that expire today. **2 emails** require policy review before sending. One restricted document was accessed from an unrecognized device.")
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.910, green: 0.918, blue: 1.0))
                .lineSpacing(3)
                .padding(.bottom, 12)

            HStack(spacing: 8) {
                Button {
                    coordinator.selectedTab = .sharing
                } label: {
                    Text("Review Shares →")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }

                NavigationLink(destination: NotificationCenterView()) {
                    Text("View Alerts →")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding(15)
        .background(
            LinearGradient(
                colors: [Color(red: 0.051, green: 0.106, blue: 0.294),
                         Color(red: 0.102, green: 0.169, blue: 0.420)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Priority Actions

    private var priorityActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Priority Actions")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)

            VStack(spacing: 8) {
                PriorityCard(
                    icon: "square.and.arrow.up.fill",
                    iconBg: danger.opacity(0.12),
                    iconColor: danger,
                    accentColor: danger,
                    title: "3 External Shares Expiring Today",
                    subtitle: "Q4-Financial-Report.pdf and 2 others. Renew or let them expire.",
                    badges: [
                        ("Restricted",    danger.opacity(0.12), danger),
                        ("Confidential",  warn.opacity(0.12),   Color(red: 0.8, green: 0.5, blue: 0.0))
                    ]
                ) { coordinator.selectedTab = .sharing }

                PriorityCard(
                    icon: "scale.3d",
                    iconBg: warn.opacity(0.12),
                    iconColor: Color(red: 0.8, green: 0.5, blue: 0.0),
                    accentColor: warn,
                    title: "2 Conversations Require Policy Review",
                    subtitle: "AI detected commitment language and PHI in outbound drafts.",
                    badges: []
                ) { coordinator.selectedTab = .email }

                NavigationLink(destination: NotificationCenterView()) {
                    PriorityCard(
                        icon: "shield.fill",
                        iconBg: brand.opacity(0.1),
                        iconColor: brand,
                        accentColor: brand,
                        title: "Pending: Acme Research Invite",
                        subtitle: "dr.chen@acme.com invited you · 32 members · Internal policy",
                        badges: []
                    ) {}
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: AI Workspace Insights

    private var aiWorkspaceInsights: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Workspace Insights")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                InsightCell(value: "247", label: "Vault Files",
                            sub: "3 restricted · 12 confidential", valueColor: brand) {
                    coordinator.selectedTab = .files
                }
                InsightCell(value: "5", label: "Unread Secure",
                            sub: "2 action required", valueColor: warn) {
                    coordinator.selectedTab = .email
                }
                InsightCell(value: "3", label: "High-Risk Shares",
                            sub: "External · expiring today", valueColor: danger) {
                    coordinator.selectedTab = .sharing
                }
                InsightCell(value: "✓", label: "Vault Secured",
                            sub: "AES-256-GCM · Enclave OK", valueColor: ok) {}
            }
        }
    }

    // MARK: Quick Access

    private var quickAccess: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Access")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)

            HStack(spacing: 8) {
                QuickAccessIcon(systemImage: "folder.fill",                   label: "Files")    { coordinator.selectedTab = .files }
                QuickAccessIcon(systemImage: "envelope.fill",                 label: "Email")    { coordinator.selectedTab = .email }
                QuickAccessIcon(systemImage: "sparkles",                      label: "AI Import") { showAIImport = true }
                QuickAccessIcon(systemImage: "arrowshape.turn.up.right.fill", label: "Sharing")  { coordinator.selectedTab = .sharing }
            }
        }
    }

    // MARK: Recent Files

    private var recentFiles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Files")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)

            VStack(spacing: 0) {
                ForEach(Array(sampleRecentFiles.enumerated()), id: \.offset) { idx, item in
                    Button { coordinator.selectedTab = .files } label: {
                        RecentFileRow(typeLabel: item.type, typeColor: item.color,
                                      name: item.name, meta: item.meta,
                                      badgeLabel: item.badge, badgeColor: item.badgeColor)
                    }
                    .buttonStyle(.plain)
                    if idx < sampleRecentFiles.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
    }

    private let sampleRecentFiles: [
        (type: String, color: Color, name: String, meta: String, badge: String, badgeColor: Color)
    ] = [
        ("PDF", Color(red: 1, green: 0.231, blue: 0.188),
         "Q4-Financial-Report.pdf",       "2.4 MB · Today",      "Restricted",   Color(red: 1,     green: 0.231, blue: 0.188)),
        ("DOC", Color(red: 0.239, green: 0.353, blue: 0.996),
         "Employee-Handbook-2026.docx",   "847 KB · Yesterday",  "Internal",     Color(red: 0.239, green: 0.353, blue: 0.996)),
        ("XLS", Color(red: 0.204, green: 0.780, blue: 0.349),
         "Budget-Planning-FY26.xlsx",     "1.1 MB · 2 days ago", "Confidential", Color(red: 1,     green: 0.584, blue: 0.000)),
    ]
}

// MARK: - Card Components

private struct PriorityCard: View {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let accentColor: Color
    let title: String
    let subtitle: String
    let badges: [(String, Color, Color)]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(iconBg)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                    if !badges.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(badges, id: \.0) { badge in
                                Text(badge.0)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(badge.2)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(badge.1))
                            }
                        }
                        .padding(.top, 3)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 13, bottomLeadingRadius: 13,
                            bottomTrailingRadius: 0, topTrailingRadius: 0)
                    )
            }
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct InsightCell: View {
    let value: String
    let label: String
    let sub: String
    let valueColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(valueColor)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct QuickAccessIcon: View {
    let systemImage: String
    let label: String
    let action: () -> Void
    private let brand = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                    .foregroundColor(brand)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct RecentFileRow: View {
    let typeLabel: String
    let typeColor: Color
    let name: String
    let meta: String
    let badgeLabel: String
    let badgeColor: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(typeColor.opacity(0.1))
                    .frame(width: 38, height: 44)
                Text(typeLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(typeColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(meta)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(badgeColor).frame(width: 6, height: 6)
                Text(badgeLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(badgeColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(badgeColor.opacity(0.1)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Compile-time stubs (real DI wired at AppCoordinator)

private final class StubRepositoryProvider: RepositoryProvider {
    var source: RepositorySource { .localVault }
    var isAvailableOffline: Bool { true }
    func listFiles(path: String) async throws -> [SecureFile] { [] }
    func fetchFile(_ file: SecureFile) async throws -> Data { Data() }
    func uploadFile(data: Data, name: String, path: String, session: XQSession) async throws -> SecureFile {
        throw RepositoryError.authenticationRequired
    }
    func deleteFile(_ file: SecureFile, session: XQSession) async throws {}
    func deltaSync(since cursor: SyncCursor?) async throws -> DeltaSyncResult {
        DeltaSyncResult(added: [], modified: [], deleted: [],
                        nextCursor: SyncCursor(token: "", fetchedAt: Date(), provider: .localVault))
    }
}

private final class StubPolicyEngine: PolicyEngine {
    var currentBundle: PolicyBundle? { nil }
    func loadBundle(_ bundle: PolicyBundle) async throws {}
    func evaluate(operation: PolicyOperation, for file: SecureFile, actor: String) async -> PolicyDecision {
        PolicyDecision(allowed: true, enforcement: .audit, citedControls: [],
                       requiredApprovalRole: nil, auditRequired: false)
    }
    func rule(for sensitivity: SensitivityLevel) -> PolicyRule? { nil }
}

#Preview {
    HomeView()
        .environmentObject(AppCoordinator())
}
