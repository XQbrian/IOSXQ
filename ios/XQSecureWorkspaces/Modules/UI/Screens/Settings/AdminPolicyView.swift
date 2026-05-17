import SwiftUI
import XQCore
import XQPolicy

struct AdminPolicyView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    // Classification Rules
    @State private var phiEnabled = true
    @State private var piiEnabled = true
    @State private var financialEnabled = true

    // Share Enforcement
    @State private var blockExternalPHI = true
    @State private var requireXQApp = true
    @State private var screenshotDetection = true

    // AI Policy
    @State private var cloudAIEnabled = false

    @State private var showSaveConfirmation = false

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let restrictedText = Color(red: 0.482, green: 0.000, blue: 0.200)
    private let restrictedBg = Color(red: 0.988, green: 0.894, blue: 0.925)

    var body: some View {
        NavigationStack {
            List {

                // MARK: Signed Policy Banner
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 24))
                            .foregroundColor(brandBlue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Policy Digitally Signed")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Version 2.4.1 · Signed by XQ Policy Authority")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.890, green: 0.949, blue: 0.992))
                            .padding(4)
                    )
                }

                // MARK: Classification Rules
                Section {
                    TogglePolicyRow(
                        icon: "heart.text.square",
                        title: "PHI Detection",
                        subtitle: "Protected Health Information",
                        isOn: $phiEnabled
                    )

                    TogglePolicyRow(
                        icon: "person.badge.key",
                        title: "PII Detection",
                        subtitle: "Personally Identifiable Information",
                        isOn: $piiEnabled
                    )

                    TogglePolicyRow(
                        icon: "dollarsign.circle",
                        title: "Financial Data",
                        subtitle: "Revenue, cost, and financial projections",
                        isOn: $financialEnabled
                    )
                } header: {
                    Text("Classification Rules")
                }

                // MARK: Share Enforcement
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Block External PHI Share")
                                        .font(.system(size: 15))
                                    Text("CRITICAL")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(restrictedText)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(restrictedBg)
                                        )
                                }
                                Text("Prevents all external sharing of PHI-classified files")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $blockExternalPHI)
                                .labelsHidden()
                                .tint(Color(red: 0.204, green: 0.780, blue: 0.349))
                        }
                    }
                    .padding(.vertical, 4)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Max Share Expiry")
                                .font(.system(size: 15))
                            Text("Maximum link lifetime for any sensitivity level")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("7 days")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    .padding(.vertical, 4)

                    TogglePolicyRow(
                        icon: "lock.shield",
                        title: "Require XQ App",
                        subtitle: "Recipients must use XQ to access",
                        isOn: $requireXQApp
                    )

                    TogglePolicyRow(
                        icon: "camera.viewfinder",
                        title: "Screenshot Detection",
                        subtitle: "Alert on screenshot in restricted files",
                        isOn: $screenshotDetection
                    )
                } header: {
                    Text("Share Enforcement")
                }

                // MARK: AI Policy Gates
                Section {
                    TogglePolicyRow(
                        icon: "cloud.fill",
                        title: "Cloud AI Processing",
                        subtitle: "Send documents to cloud AI for classification",
                        isOn: $cloudAIEnabled
                    )

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(red: 1.000, green: 0.584, blue: 0.000))
                            .font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CUI/PHI = Local Only Always")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Classified or PHI-flagged documents are always processed on-device regardless of this setting. This cannot be overridden.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 1.000, green: 0.973, blue: 0.882))
                            .padding(4)
                    )
                } header: {
                    Text("AI Policy Gates")
                }

                // MARK: Action Buttons
                Section {
                    Button {
                        showSaveConfirmation = true
                    } label: {
                        Text("Publish Policy Update")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(brandBlue))
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    Button {
                        dismiss()
                    } label: {
                        Text("Discard Changes")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(brandBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(brandBlue, lineWidth: 1.5)
                            )
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listSectionSeparator(.hidden)
            }
            .navigationTitle("Policy Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        showSaveConfirmation = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(brandBlue)
                }
            }
            .alert("Publish Policy", isPresented: $showSaveConfirmation) {
                Button("Publish", role: .none) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will push the updated policy to all 142 enterprise tenants immediately.")
            }
        }
    }
}

// MARK: - Supporting Views

private struct TogglePolicyRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(red: 0.204, green: 0.780, blue: 0.349))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AdminPolicyView()
        .environmentObject(AppCoordinator())
}
