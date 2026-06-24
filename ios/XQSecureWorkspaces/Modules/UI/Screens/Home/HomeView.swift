import SwiftUI
import XQCore

struct HomeView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = HomeViewModel(
        repository: StubRepositoryProvider(),
        policyEngine: StubPolicyEngine()
    )

    @State private var showNotifications = false
    @State private var showWorkgroupSelect = false
    @State private var selectedFile: SecureFile?
    @State private var showAIImport = false

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Risk Alert
                    if let firstAlert = vm.riskAlerts.first {
                        RiskAlertCard(
                            title: "Policy Alert — Restricted File",
                            description: "A file contains PHI detected by AI scanner. External share blocked.",
                            actionLabel: "Review file →",
                            action: {
                                if let file = vm.recentFiles.first(where: { $0.sensitivity == .restricted }) {
                                    selectedFile = file
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .id(firstAlert.id)
                    }

                    // Quick Actions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Actions")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .kerning(0.5)
                            .padding(.horizontal, 20)

                        VStack(spacing: 9) {
                            HStack(spacing: 9) {
                                PrimaryActionCard(
                                    systemImage: "folder.fill",
                                    label: "Files",
                                    sublabel: "Browse & share"
                                ) { coordinator.selectedTab = .files }
                                PrimaryActionCard(
                                    systemImage: "envelope.fill",
                                    label: "Email",
                                    sublabel: "Secure inbox"
                                ) { coordinator.selectedTab = .messages }
                            }
                            HStack(spacing: 9) {
                                SecondaryActionCard(
                                    systemImage: "sparkles",
                                    label: "AI Import"
                                ) { showAIImport = true }
                                SecondaryActionCard(
                                    systemImage: "bell.fill",
                                    label: "Alerts"
                                ) { coordinator.selectedTab = .alerts }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Recent Files
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Files")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .kerning(0.5)
                            .padding(.horizontal, 20)

                        if vm.recentFiles.isEmpty && !vm.isLoading {
                            Text("No recent files")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(vm.recentFiles.prefix(5)) { file in
                                    Button {
                                        selectedFile = file
                                    } label: {
                                        FileRowView(file: file)
                                            .background(Color(.systemBackground))
                                    }
                                    .buttonStyle(.plain)

                                    if file.id != vm.recentFiles.prefix(5).last?.id {
                                        Divider()
                                            .padding(.leading, 68)
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                            .padding(.horizontal, 16)
                        }
                    }

                    // Vault Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vault Status")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .kerning(0.5)
                            .padding(.horizontal, 20)

                        HStack(spacing: 0) {
                            VaultStatCell(
                                value: "\(vm.vaultStats.total)",
                                label: "Total",
                                color: brandBlue
                            )

                            Divider().frame(height: 40)

                            VaultStatCell(
                                value: "\(vm.vaultStats.confidential)",
                                label: "Confidential",
                                color: Color(red: 0.427, green: 0.298, blue: 0.000)
                            )

                            Divider().frame(height: 40)

                            VaultStatCell(
                                value: "\(vm.vaultStats.restricted)",
                                label: "Restricted",
                                color: Color(red: 0.482, green: 0.000, blue: 0.200)
                            )
                        }
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            showNotifications = true
                        } label: {
                            Image(systemName: "bell")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }

                        Button {
                            coordinator.selectedTab = .settings
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(brandBlue)
                                    .frame(width: 36, height: 36)
                                Text("BW")
                                    .font(.system(size: 13, weight: .bold))
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
            .onChange(of: showNotifications) { _, show in
                if show {
                    showNotifications = false
                    coordinator.selectedTab = .alerts
                }
            }
            .sheet(isPresented: $showWorkgroupSelect) {
                WorkgroupSelectView()
            }
            .sheet(item: $selectedFile) { file in
                NavigationStack { FileViewerView(file: file) }
            }
            .sheet(isPresented: $showAIImport) {
                AIImportView()
            }
        }
    }
}

// MARK: - Supporting Views

private struct PrimaryActionCard: View {
    let systemImage: String
    let label: String
    let sublabel: String
    let action: () -> Void

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 28))
                    .foregroundColor(brandBlue)
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text(sublabel)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct SecondaryActionCard: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundColor(brandBlue)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct VaultStatCell: View {
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

// MARK: - Stub Dependencies (compile stubs; real DI wired at composition root)

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
        PolicyDecision(allowed: true, enforcement: .audit, citedControls: [], requiredApprovalRole: nil, auditRequired: false)
    }
    func rule(for sensitivity: SensitivityLevel) -> PolicyRule? { nil }
}

#Preview {
    HomeView()
        .environmentObject(AppCoordinator())
}
