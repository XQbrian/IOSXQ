import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var step = 0
    @State private var selectedRepo: RepoType? = nil
    @State private var biometricEnabled = true
    @State private var notificationsEnabled = true
    @State private var filesAccessEnabled = true

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.top, 16)

            TabView(selection: $step) {
                repoStep.tag(0)
                permissionsStep.tag(1)
                aiModelStep.tag(2)
                doneStep.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)

            navigationRow
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 2)
                    .fill(idx <= step ? brandBlue : Color(.systemGray5))
                    .frame(height: 3)
                    .animation(.easeInOut, value: step)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Step: Choose Repo

    private var repoStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                stepHeader(
                    icon: "externaldrive.fill",
                    title: "Connect Your Repository",
                    subtitle: "Choose where your secure files live. XQ encrypts everything locally before syncing."
                )
                VStack(spacing: 12) {
                    ForEach(RepoType.allCases, id: \.self) { repo in
                        RepoOptionCard(repo: repo, isSelected: selectedRepo == repo) {
                            selectedRepo = repo
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Step: Permissions

    private var permissionsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                stepHeader(
                    icon: "hand.raised.fill",
                    title: "Grant Permissions",
                    subtitle: "XQ needs these permissions to protect your data. None are shared with third parties."
                )
                VStack(spacing: 0) {
                    PermissionRow(icon: "faceid", label: "Face ID",
                                  detail: "Lock the app after 2 minutes of inactivity",
                                  isEnabled: $biometricEnabled)
                    Divider().padding(.leading, 56)
                    PermissionRow(icon: "bell.fill", label: "Notifications",
                                  detail: "Security alerts and share expiry reminders",
                                  isEnabled: $notificationsEnabled)
                    Divider().padding(.leading, 56)
                    PermissionRow(icon: "folder.fill", label: "Files Access",
                                  detail: "Import and export encrypted files",
                                  isEnabled: $filesAccessEnabled)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                .padding(.horizontal, 24)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Step: AI Model

    private var aiModelStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "brain",
                title: "Download AI Models",
                subtitle: "On-device CoreML models power file classification and email intelligence — no cloud required."
            )
            VStack(spacing: 12) {
                ModelRow(name: "File Classifier", size: "42 MB", status: .downloaded)
                ModelRow(name: "Entity Extractor", size: "118 MB", status: .downloaded)
                ModelRow(name: "Threat Detector", size: "67 MB", status: .downloading(progress: 0.72))
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .padding(.top, 16)
    }

    // MARK: - Step: Done

    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(red: 0.204, green: 0.780, blue: 0.349).opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(red: 0.204, green: 0.780, blue: 0.349))
            }
            Text("You're Protected")
                .font(.system(size: 26, weight: .bold))
            Text("XQ Secure Workspaces is ready. Your files are encrypted and your vault is active.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Navigation Row

    private var navigationRow: some View {
        HStack {
            if step > 0 {
                Button {
                    step -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(brandBlue)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                }
            } else {
                Spacer().frame(width: 44)
            }

            Spacer()

            if step < totalSteps - 1 {
                Button {
                    step += 1
                } label: {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(brandBlue))
                }
            } else {
                HStack(spacing: 12) {
                    Button {
                        coordinator.completeOnboarding()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Button {
                        coordinator.completeOnboarding()
                    } label: {
                        Text("Get Started")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.204, green: 0.780, blue: 0.349))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Header Helper

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(brandBlue)
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Sub-views

private struct RepoOptionCard: View {
    let repo: RepoType
    let isSelected: Bool
    let action: () -> Void

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: repo.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .white : brandBlue)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? brandBlue : brandBlue.opacity(0.1))
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(repo.label)
                        .font(.system(size: 15, weight: .semibold))
                    Text(repo.detail)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(brandBlue)
                }
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? brandBlue : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct PermissionRow: View {
    let icon: String
    let label: String
    let detail: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.239, green: 0.353, blue: 0.996))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(Color(red: 0.204, green: 0.780, blue: 0.349))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct ModelRow: View {
    let name: String
    let size: String
    let status: ModelStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.239, green: 0.353, blue: 0.996))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14, weight: .semibold))
                Text(size).font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer()
            statusView
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(red: 0.204, green: 0.780, blue: 0.349))
        case .downloading(let progress):
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .frame(width: 60)
                    .tint(Color(red: 0.239, green: 0.353, blue: 0.996))
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Enums

enum RepoType: CaseIterable {
    case sharePoint, smb, googleDrive, localVault

    var icon: String {
        switch self {
        case .sharePoint:  return "building.2.fill"
        case .smb:         return "externaldrive.badge.wifi"
        case .googleDrive: return "externaldrive.fill"
        case .localVault:  return "lock.fill"
        }
    }

    var label: String {
        switch self {
        case .sharePoint:  return "SharePoint / OneDrive"
        case .smb:         return "SMB Network Share"
        case .googleDrive: return "Google Drive"
        case .localVault:  return "Local Vault Only"
        }
    }

    var detail: String {
        switch self {
        case .sharePoint:  return "Microsoft 365 enterprise storage"
        case .smb:         return "On-premises file server"
        case .googleDrive: return "Google Workspace integration"
        case .localVault:  return "Files stay on this device only"
        }
    }
}

enum ModelStatus {
    case downloaded
    case downloading(progress: Double)
}
