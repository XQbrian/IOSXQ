import SwiftUI
import XQCore
import XQPolicy

struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var appTheme: AppTheme

    @AppStorage("xq.biometricLock") private var biometricLock = true
    @State private var cloudAIEnabled = false
    @State private var phishingAlerts = true
    @State private var phiDetectionBanners = true
    @State private var policyPanels = true
    @State private var aiIntelPanels = true
    @State private var showSignOutConfirm = false
    @State private var showWorkspaces = false

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let green = Color(red: 0.204, green: 0.780, blue: 0.349)

    var body: some View {
        NavigationStack {
            List {

                // MARK: Account Section
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(brandBlue)
                                .frame(width: 64, height: 64)
                            Text("BW")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Brian Wane")
                                .font(.system(size: 17, weight: .semibold))

                            Text("brian@xqmsg.com")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            Text("ENTERPRISE ADMIN")
                                .font(.system(size: 9, weight: .bold))
                                .kerning(0.5)
                                .foregroundColor(brandBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.910, green: 0.918, blue: 0.992))
                                )
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Account")
                }

                // MARK: Security Section
                Section {
                    HStack {
                        Label("Biometric Lock", systemImage: "faceid")
                        Spacer()
                        Toggle("", isOn: $biometricLock)
                            .labelsHidden()
                            .tint(green)
                    }

                    HStack {
                        Label("Auto-lock", systemImage: "lock.rotation")
                        Spacer()
                        Text("2 min")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(.tertiaryLabel))
                    }

                    HStack {
                        Label("Certificate Pinning", systemImage: "shield.checkerboard")
                        Spacer()
                        HStack(spacing: 5) {
                            Circle().fill(green).frame(width: 7, height: 7)
                            Text("Active").foregroundColor(green).font(.system(size: 14))
                        }
                    }
                } header: {
                    Text("Security")
                }

                // MARK: Notifications Section
                Section {
                    HStack {
                        Label("Phishing Alerts", systemImage: "exclamationmark.triangle.fill")
                        Spacer()
                        Toggle("", isOn: $phishingAlerts).labelsHidden().tint(green)
                    }
                    HStack {
                        Label("PHI Detection Banners", systemImage: "cross.fill")
                        Spacer()
                        Toggle("", isOn: $phiDetectionBanners).labelsHidden().tint(green)
                    }
                    HStack {
                        Label("Policy & Compliance Panels", systemImage: "doc.badge.gearshape")
                        Spacer()
                        Toggle("", isOn: $policyPanels).labelsHidden().tint(green)
                    }
                    HStack {
                        Label("AI Intelligence Panels", systemImage: "brain")
                        Spacer()
                        Toggle("", isOn: $aiIntelPanels).labelsHidden().tint(green)
                    }
                } header: {
                    Text("Notifications")
                }

                // MARK: Enterprise Admin Section
                Section {
                    Button {
                        showWorkspaces = true
                    } label: {
                        HStack {
                            Label("My Workspaces", systemImage: "person.3.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }

                    // Push AdminPolicyView onto SettingsView's NavigationStack
                    // so the user gets a system back button. Avoids the previous
                    // `coordinator.navigate(to: .adminPolicy)` which replaced the
                    // entire root view and trapped the user.
                    NavigationLink(destination: AdminPolicyView()) {
                        HStack {
                            Label("Policy Management", systemImage: "doc.badge.gearshape")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }

                    HStack {
                        Label("Cloud AI Processing", systemImage: "brain")
                        Spacer()
                        Toggle("", isOn: $cloudAIEnabled).labelsHidden().tint(green)
                    }

                    HStack {
                        Label("Enterprise Tenants", systemImage: "building.2")
                        Spacer()
                        Text("142").foregroundColor(.secondary)
                    }
                } header: {
                    Text("Enterprise Admin")
                } footer: {
                    Text("You have enterprise administrator privileges for this organization.")
                        .font(.system(size: 12))
                }

                // MARK: Appearance Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 10) {
                            ForEach(AppThemeMode.allCases, id: \.self) { mode in
                                ThemeButton(
                                    mode: mode,
                                    isSelected: appTheme.mode == mode
                                ) {
                                    appTheme.mode = mode
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Appearance")
                }

                // MARK: About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    HStack {
                        Label("XQ API", systemImage: "network")
                        Spacer()
                        Text("v3").foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Secure Enclave", systemImage: "cpu.fill")
                        Spacer()
                        HStack(spacing: 5) {
                            Circle().fill(green).frame(width: 7, height: 7)
                            Text("Active").foregroundColor(green).font(.system(size: 14))
                        }
                    }
                    HStack {
                        Label("CoreML Models", systemImage: "sparkles")
                        Spacer()
                        Text("3 models").foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // MARK: Sign Out
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out").font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                    }
                }

            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) { coordinator.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will be signed out of your enterprise account.")
            }
            .sheet(isPresented: $showWorkspaces) { WorkspacesGroupsView() }
        }
    }
}

// MARK: - Theme Button

private struct ThemeButton: View {
    let mode: AppThemeMode
    let isSelected: Bool
    let action: () -> Void

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                let (top, bottom) = mode.swatchColors
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [top, bottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? brandBlue : Color.clear, lineWidth: 2)
                    )
                Text(mode.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? brandBlue : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppCoordinator())
        .environmentObject(AppTheme())
}
