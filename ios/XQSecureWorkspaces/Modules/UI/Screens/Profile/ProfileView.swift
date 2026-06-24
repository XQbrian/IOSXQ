import SwiftUI

/// Profile — the command center reached from the top-right [BW] avatar on
/// every top-level screen. Mirrors `s-profile` in the HTML prototype:
/// identity card → Security Health → Quick Actions → sticky quick-nav chips
/// → 8 stacked subsections. Presented as a `.sheet` from MainTabView.
///
/// Currently a Phase-1 alignment surface — covers the prototype's IA and the
/// most important content per subsection. Per-subsection deep-link, native
/// theme picker, real revocation/MFA, etc., are deferred to follow-up
/// work tracked in `SWIFT_BUILD_STATUS.md`.
struct ProfileView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var activeSection: ProfileSection = ProfileView.loadLastSection()

    private let brand = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let ok    = Color(red: 0.204, green: 0.780, blue: 0.349)
    private let warn  = Color(red: 1.000, green: 0.584, blue: 0.000)
    private let res   = Color(red: 0.776, green: 0.157, blue: 0.157)

    private static let sectionKey = "xq.profileSection"

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroller in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                        identityCard
                            .padding(.top, 8)
                        securityHealthCard
                        quickActions
                        Section(header: quickNavBar(scroller: scroller)) {
                            VStack(alignment: .leading, spacing: 18) {
                                ForEach(ProfileSection.allCases, id: \.self) { section in
                                    sectionContent(section)
                                        .id(section)
                                }
                            }
                            .padding(.top, 8)
                        }
                        signOutButton
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 16)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { coordinator.dismissProfile() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(brand)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 5) {
                        Circle().fill(ok).frame(width: 7, height: 7)
                        Text("Compliant")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ok)
                    }
                }
            }
        }
    }

    // MARK: - Identity card

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 13) {
                ZStack {
                    Circle().fill(brand)
                    Text("BW")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Brian Wane")
                        .font(.system(size: 17, weight: .bold))
                    Text("Enterprise Admin · Compliance")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Acme Health Systems")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.tertiaryLabel))
                    HStack(spacing: 5) {
                        statusBadge(text: "● Verified", color: ok, bg: ok.opacity(0.12))
                        statusBadge(text: "ENT ADMIN", color: brand, bg: brand.opacity(0.12))
                    }
                    .padding(.top, 4)
                }
                Spacer()
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

            Text("Last login: Today 9:14 AM · iPhone 15 Pro · San Francisco, CA")
                .font(.system(size: 10))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Security Health card

    private var securityHealthCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Security Health")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                healthTile(icon: "lock.shield.fill",   color: ok,    title: "MFA Enabled",      subtitle: "Authenticator · TouchID")
                healthTile(icon: "laptopcomputer",      color: brand, title: "3 Active Sessions", subtitle: "iPhone · Mac · iPad")
                healthTile(icon: "checkmark.seal.fill", color: ok,    title: "Policy Compliant", subtitle: "12/12 controls passing")
                healthTile(icon: "shield.fill",         color: ok,    title: "Encryption OK",    subtitle: "AES-256-GCM · Enclave")
            }
        }
    }

    private func healthTile(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            Text(subtitle).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Quick Actions")
            HStack(spacing: 6) {
                quickActionTile(icon: "key.fill",          title: "Change\nPassword") { activeSection = .security; persist(.security) }
                quickActionTile(icon: "laptopcomputer",    title: "Manage\nDevices")  { activeSection = .devices;  persist(.devices) }
                quickActionTile(icon: "lock.shield.fill",  title: "Configure\nMFA")   { activeSection = .security; persist(.security) }
                quickActionTile(icon: "arrow.down.circle.fill", title: "Audit\nLogs") { activeSection = .admin;    persist(.admin) }
            }
        }
    }

    private func quickActionTile(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17)).foregroundColor(brand)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 11).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick-nav chip bar (sticky)

    private func quickNavBar(scroller: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ProfileSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            activeSection = section
                            persist(section)
                            scroller.scrollTo(section, anchor: .top)
                        }
                    } label: {
                        Text(section.label)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 6)
                            .background(activeSection == section ? brand : Color(.secondarySystemBackground))
                            .foregroundColor(activeSection == section ? .white : .secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Subsection content

    @ViewBuilder
    private func sectionContent(_ section: ProfileSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.label)
                .font(.system(size: 15, weight: .bold))
            switch section {
            case .general:       generalContent
            case .security:      securityContent
            case .notifications: notificationsContent
            case .integrations:  integrationsContent
            case .workspace:     workspaceContent
            case .devices:       devicesContent
            case .billing:       billingContent
            case .admin:         adminContent
            }
        }
    }

    private var generalContent: some View {
        VStack(spacing: 0) {
            rowKV("Display Name", "Brian Wane")
            rowKV("Email",        "brian@xqmsg.com")
            rowKV("Role",         "ENTERPRISE ADMIN")
            rowKV("Language",     "English (US)")
            rowKV("Time Zone",    "America/Los_Angeles")
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var securityContent: some View {
        VStack(spacing: 0) {
            rowKV("Multi-Factor Auth",  "On")
            rowKV("Biometric Lock",     "On")
            rowKV("Auto-lock",          "2 min")
            rowKV("Certificate Pinning","Active")
            rowKV("At-Rest Encryption", "AES-256-GCM")
            rowKV("Secure Enclave",     "Key custody OK")
            rowKV("Jailbreak Detection","Clean")
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var notificationsContent: some View {
        VStack(spacing: 0) {
            rowKV("Phishing Alerts",          "On")
            rowKV("PHI Detection Banners",    "On")
            rowKV("Policy & Compliance",      "On")
            rowKV("AI Intelligence Panels",   "On")
            rowKV("Push Notifications",       "On")
            rowKV("Email Digest",             "Weekly")
            rowKV("Critical Alerts via SMS",  "Off")
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var integrationsContent: some View {
        VStack(spacing: 0) {
            rowKV("SharePoint",   "● Connected")
            rowKV("OneDrive",     "● Connected")
            rowKV("Entra ID SSO", "● Active")
            rowKV("Outlook 365",  "● Connected")
            rowKV("Slack",        "Connect")
            rowKV("Okta",         "Connect")
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var workspaceContent: some View {
        VStack(spacing: 0) {
            rowKV("Organization",       "Acme Health Systems")
            rowKV("Tenant ID",          "ahs-prod-9d4e7")
            rowKV("Plan Tier",          "ENTERPRISE")
            rowKV("Data Residency",     "US-West (Oregon)")
            rowKV("Compliance Posture", "HIPAA · SOC 2 Type II")
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var devicesContent: some View {
        VStack(spacing: 0) {
            rowKV("iPhone 15 Pro",    "CURRENT")
            rowKV("MacBook Pro 14\"", "Revoke")
            rowKV("iPad Pro 13\"",    "Revoke")
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var billingContent: some View {
        VStack(spacing: 0) {
            rowKV("Plan",          "ENTERPRISE")
            rowKV("Seats",         "142 / 200")
            rowKV("Billing Cycle", "Annual")
            rowKV("Next Renewal",  "Jan 14, 2027")
            rowKV("Card on File",  "Visa •••• 4242")
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var adminContent: some View {
        VStack(spacing: 0) {
            rowKV("Policy Bundle",          "Signed · v2.1.4")
            rowKV("PHI Auto-detection",     "On")
            rowKV("Block External PHI",     "On (Critical)")
            rowKV("Max Share Expiry",       "7 days")
            rowKV("Cloud AI Processing",    "Off (Local Only)")
            rowKV("Tenant Users",           "142")
            rowKV("Audit Log Export",       "Download CSV")
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button(role: .destructive) {
            coordinator.dismissProfile()
            coordinator.signOut()
        } label: {
            Text("Sign out")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.separator), lineWidth: 1))
        }
    }

    // MARK: - Reusable bits

    private func rowKV(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(Divider().padding(.leading, 16), alignment: .bottom)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .kerning(0.4)
            .textCase(.uppercase)
            .foregroundColor(.secondary)
            .padding(.horizontal, 2)
    }

    private func statusBadge(text: String, color: Color, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(bg))
            .foregroundColor(color)
    }

    // MARK: - Section persistence (mirrors xq.profileSection in HTML)

    private static func loadLastSection() -> ProfileSection {
        let raw = UserDefaults.standard.string(forKey: sectionKey) ?? ""
        return ProfileSection(rawValue: raw) ?? .general
    }

    private func persist(_ section: ProfileSection) {
        UserDefaults.standard.set(section.rawValue, forKey: Self.sectionKey)
    }
}

// MARK: - Sections

enum ProfileSection: String, CaseIterable {
    case general       = "general"
    case security      = "security"
    case notifications = "notifications"
    case integrations  = "integrations"
    case workspace     = "workspace"
    case devices       = "devices"
    case billing       = "billing"
    case admin         = "admin"

    var label: String {
        switch self {
        case .general:       return "General"
        case .security:      return "Security"
        case .notifications: return "Notifications"
        case .integrations:  return "Integrations"
        case .workspace:     return "Workspace"
        case .devices:       return "Devices"
        case .billing:       return "Billing"
        case .admin:         return "Admin"
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppCoordinator())
}
