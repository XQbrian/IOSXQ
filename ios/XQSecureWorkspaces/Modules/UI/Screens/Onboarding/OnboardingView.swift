import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    // Step order: 0=repo, 1=workgroup, 2=permissions, 3=done
    @State private var step = 0
    @State private var selectedRepo: RepoType = .localVault     // Local Files default
    @State private var selectedWorkgroupId: UUID? = Workgroup.samples.first?.id
    @State private var biometricEnabled = true
    @State private var notificationsEnabled = true
    @State private var filesAccessEnabled = true
    @State private var emailConnectEnabled = false
    @State private var selectedEmailProvider: EmailProvider? = nil

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            progressBar.padding(.top, 16)

            TabView(selection: $step) {
                repoStep.tag(0)
                workgroupStep.tag(1)
                permissionsStep.tag(2)
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

    // MARK: - Step 0: Connect Workspace

    private var repoStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                stepHeader(
                    icon: "externaldrive.fill",
                    title: "Connect Your Workspace",
                    subtitle: "Choose your file repository. All data stays encrypted end-to-end."
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

    // MARK: - Step 1: Select Workgroup

    private var workgroupStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "person.3.fill",
                    title: "Select Workspace",
                    subtitle: "Join a shared encrypted vault, or skip to continue with your personal vault."
                )

                AIGuideCard(
                    message: "A workspace lets you share encrypted files with your team under a shared policy. You can always switch later.",
                    chips: [
                        ("What is a workspace?",
                         "A workspace is an encrypted vault shared with your team. Each member holds a key shard — no single person can open files alone."),
                        ("Can I change later?",
                         "Yes, easily. Switch workspaces anytime from Settings or the home screen."),
                        ("Skip for clinical?",
                         "If you're in a clinical environment, select your specific department group to inherit its HIPAA policy automatically.")
                    ]
                )
                .padding(.horizontal, 24)

                VStack(spacing: 0) {
                    ForEach(Array(Workgroup.samples.enumerated()), id: \.element.id) { idx, wg in
                        Button {
                            selectedWorkgroupId = wg.id
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedWorkgroupId == wg.id
                                              ? brandBlue : brandBlue.opacity(0.1))
                                        .frame(width: 46, height: 46)
                                    Text(wg.initials)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(selectedWorkgroupId == wg.id ? .white : brandBlue)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(wg.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    HStack(spacing: 8) {
                                        Label("\(wg.memberCount)", systemImage: "person.2")
                                            .font(.system(size: 11))
                                        Label("\(wg.fileCount) files", systemImage: "folder")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedWorkgroupId == wg.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(brandBlue)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if idx < Workgroup.samples.count - 1 {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                .padding(.horizontal, 24)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Step 2: Allow Access

    private var permissionsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "hand.raised.fill",
                    title: "Allow Access",
                    subtitle: "XQ needs these permissions to protect your data. None are shared with third parties."
                )

                AIGuideCard(
                    message: "Last step — I need a few device permissions to keep your files secure. Each one is optional, but skipping them limits what XQ can protect.",
                    chips: [
                        ("Why Face ID?",
                         "Face ID is used exclusively to unlock the Secure Enclave, where your encryption keys live. It never leaves your device."),
                        ("Is my email safe?",
                         "XQ reads email metadata (sender, subject) on-device to classify sensitivity. No email content ever leaves your device."),
                        ("Can I skip all?",
                         "You can skip any permission now and enable it later in Settings. Some features like auto-lock require Face ID.")
                    ]
                )
                .padding(.horizontal, 24)

                VStack(spacing: 0) {
                    PermissionRow(
                        icon: "faceid",
                        label: "Face ID / Touch ID",
                        detail: "Required for Secure Enclave key access",
                        iconBg: Color(red: 0.941, green: 0.953, blue: 1.0),
                        iconColor: brandBlue,
                        isEnabled: $biometricEnabled
                    )
                    Divider().padding(.leading, 68)
                    PermissionRow(
                        icon: "bell.fill",
                        label: "Notifications",
                        detail: "Policy alerts and security events",
                        iconBg: Color(red: 1.0, green: 0.953, blue: 0.878),
                        iconColor: .orange,
                        isEnabled: $notificationsEnabled
                    )
                    Divider().padding(.leading, 68)
                    PermissionRow(
                        icon: "folder.fill",
                        label: "Files Access",
                        detail: "Import from Files app and iCloud",
                        iconBg: Color(red: 0.910, green: 0.973, blue: 0.914),
                        iconColor: Color(red: 0.180, green: 0.490, blue: 0.196),
                        isEnabled: $filesAccessEnabled
                    )
                    Divider().padding(.leading, 68)
                    EmailConnectRow(
                        isEnabled: $emailConnectEnabled,
                        selectedProvider: $selectedEmailProvider
                    )
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
                .padding(.horizontal, 24)

                Text("You can change these anytime in Settings")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Step 3: Done

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
                Button { step -= 1 } label: {
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

            switch step {
            case 1:
                HStack(spacing: 12) {
                    Button { step += 1 } label: {
                        Text("Skip")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    continueButton(label: "Continue")
                }
            case 2:
                continueButton(label: "Finish Setup")
            case totalSteps - 1:
                Button { coordinator.completeOnboarding() } label: {
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
            default:
                continueButton(label: "Continue")
            }
        }
    }

    private func continueButton(label: String) -> some View {
        Button { step += 1 } label: {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(brandBlue))
        }
    }

    // MARK: - Step Header

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

// MARK: - AI Guide Card

private struct AIGuideCard: View {
    let message: String
    let chips: [(String, String)]  // (label, answer)

    @State private var currentAnswer: String? = nil
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [brandBlue, Color(red: 0.412, green: 0.471, blue: 0.973)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    Text("✦")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("XQ SETUP GUIDE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(brandBlue)
                        .kerning(0.3)
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let answer = currentAnswer {
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(brandBlue)
                        .frame(width: 3)
                    Text(answer)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 6) {
                ForEach(chips, id: \.0) { label, answer in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentAnswer = answer
                        }
                    } label: {
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(brandBlue)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(brandBlue.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(brandBlue.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(brandBlue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(brandBlue.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Repo Option Card

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
                    .foregroundColor(isSelected ? .white : repo.iconColor)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? brandBlue : repo.iconColor.opacity(0.1))
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(repo.label).font(.system(size: 15, weight: .semibold))
                    Text(repo.detail).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(brandBlue)
                }
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? brandBlue : Color.clear, lineWidth: 2))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let label: String
    let detail: String
    let iconBg: Color
    let iconColor: Color
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 11).fill(iconBg))
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

// MARK: - Email Connect Row

private struct EmailConnectRow: View {
    @Binding var isEnabled: Bool
    @Binding var selectedProvider: EmailProvider?

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 18))
                    .foregroundColor(brandBlue)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(Color(red: 0.910, green: 0.918, blue: 0.992))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Email").font(.system(size: 14, weight: .semibold))
                    Text("Encrypt outbound emails automatically")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(Color(red: 0.204, green: 0.780, blue: 0.349))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if isEnabled {
                Divider().padding(.leading, 16)
                VStack(alignment: .leading, spacing: 0) {
                    Text("CHOOSE EMAIL PROVIDER")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .kerning(0.3)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    ForEach(EmailProvider.allCases, id: \.self) { provider in
                        Button {
                            selectedProvider = provider
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: provider.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(provider.iconColor)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.label)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(provider.detail)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Circle()
                                    .fill(selectedProvider == provider ? brandBlue : Color.clear)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle().stroke(
                                            selectedProvider == provider
                                                ? brandBlue : Color(.separator),
                                            lineWidth: 2)
                                    )
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        if provider != EmailProvider.allCases.last {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.2), value: isEnabled)
            }
        }
    }
}

// MARK: - Enums

enum RepoType: CaseIterable {
    case localVault, sharePoint, smb, googleDrive

    var icon: String {
        switch self {
        case .localVault:  return "internaldrive.fill"
        case .sharePoint:  return "building.2.fill"
        case .smb:         return "externaldrive.badge.wifi"
        case .googleDrive: return "externaldrive.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .localVault:  return Color(red: 0.239, green: 0.353, blue: 0.996)
        case .sharePoint:  return Color(red: 0.0, green: 0.471, blue: 0.831)
        case .smb:         return .secondary
        case .googleDrive: return Color(red: 0.259, green: 0.522, blue: 0.957)
        }
    }

    var label: String {
        switch self {
        case .localVault:  return "Local Files"
        case .sharePoint:  return "SharePoint / OneDrive"
        case .smb:         return "SMB Network Drive"
        case .googleDrive: return "Google Drive"
        }
    }

    var detail: String {
        switch self {
        case .localVault:  return "On-device vault · No cloud required"
        case .sharePoint:  return "Microsoft 365 · OAuth PKCE"
        case .smb:         return "Corporate LAN / VPN"
        case .googleDrive: return "Google Workspace · OAuth 2.0"
        }
    }
}

enum EmailProvider: CaseIterable, Equatable {
    case microsoft365, gmail, imap

    var label: String {
        switch self {
        case .microsoft365: return "Microsoft 365 / Outlook"
        case .gmail:        return "Gmail / Google Workspace"
        case .imap:         return "Custom IMAP / SMTP"
        }
    }

    var detail: String {
        switch self {
        case .microsoft365: return "OAuth · Exchange Online"
        case .gmail:        return "OAuth 2.0 · IMAP bridge"
        case .imap:         return "Any mail server · manual config"
        }
    }

    var icon: String {
        switch self {
        case .microsoft365: return "envelope.badge.fill"
        case .gmail:        return "envelope.fill"
        case .imap:         return "gearshape.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .microsoft365: return Color(red: 0.0, green: 0.471, blue: 0.831)
        case .gmail:        return Color(red: 0.851, green: 0.263, blue: 0.220)
        case .imap:         return .secondary
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppCoordinator())
}
