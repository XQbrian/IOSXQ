import SwiftUI
import XQCore
import XQPolicy

struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var biometricLock = true
    @State private var cloudAIEnabled = false

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

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
                            .tint(Color(red: 0.204, green: 0.780, blue: 0.349))
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
                            Circle()
                                .fill(Color(red: 0.204, green: 0.780, blue: 0.349))
                                .frame(width: 7, height: 7)
                            Text("Active")
                                .foregroundColor(Color(red: 0.204, green: 0.780, blue: 0.349))
                                .font(.system(size: 14))
                        }
                    }
                } header: {
                    Text("Security")
                }

                // MARK: Enterprise Admin Section
                Section {
                    Button {
                        coordinator.navigate(to: .adminPolicy)
                    } label: {
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
                        Toggle("", isOn: $cloudAIEnabled)
                            .labelsHidden()
                            .tint(Color(red: 0.204, green: 0.780, blue: 0.349))
                    }

                    HStack {
                        Label("Enterprise Tenants", systemImage: "building.2")
                        Spacer()
                        Text("142")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Enterprise Admin")
                } footer: {
                    Text("You have enterprise administrator privileges for this organization.")
                        .font(.system(size: 12))
                }

                // MARK: About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("XQ API", systemImage: "network")
                        Spacer()
                        Text("v3")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Secure Enclave", systemImage: "cpu.fill")
                        Spacer()
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(red: 0.204, green: 0.780, blue: 0.349))
                                .frame(width: 7, height: 7)
                            Text("Active")
                                .foregroundColor(Color(red: 0.204, green: 0.780, blue: 0.349))
                                .font(.system(size: 14))
                        }
                    }

                    HStack {
                        Label("CoreML Models", systemImage: "sparkles")
                        Spacer()
                        Text("3 models")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }

            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppCoordinator())
}
