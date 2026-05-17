import SwiftUI
import XQCore
import XQPolicy

struct SecureShareSheet: View {
    @Binding var isPresented: Bool

    @State private var step = 1
    @State private var recipientEmail = ""
    @State private var recipients: [String] = []
    @State private var expiryEnabled = true
    @State private var screenshotDetection = true
    @State private var requireXQApp = true
    @State private var auditLog = true

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.separator))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 14)

            // Step dots
            HStack(spacing: 7) {
                ForEach(1...totalSteps, id: \.self) { i in
                    if i == step {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(brandBlue)
                            .frame(width: 24, height: 8)
                    } else {
                        Circle()
                            .fill(Color(.separator))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: step)
            .padding(.bottom, 18)

            // Content
            Group {
                switch step {
                case 1: step1View
                case 2: step2View
                case 3: step3View
                case 4: step4View
                default: EmptyView()
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            // Navigation buttons
            if step < totalSteps {
                Button {
                    withAnimation { step += 1 }
                } label: {
                    Text(step == 1 ? "Analyze Risk" : step == 2 ? "Configure Settings" : "Send Securely")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16).fill(brandBlue))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 44)
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Step 1: Recipients

    private var step1View: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Share Securely")
                    .font(.system(size: 19, weight: .bold))
                Text("Add recipients to share this file")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)

            HStack(spacing: 8) {
                TextField("recipient@company.com", text: $recipientEmail)
                    .font(.system(size: 15))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                    )

                Button {
                    let trimmed = recipientEmail.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        recipients.append(trimmed)
                        recipientEmail = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(brandBlue)
                }
            }

            if !recipients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recipients, id: \.self) { email in
                            HStack(spacing: 6) {
                                Text(email)
                                    .font(.system(size: 13))
                                    .foregroundColor(brandBlue)
                                Button {
                                    recipients.removeAll { $0 == email }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.910, green: 0.918, blue: 0.992))
                            )
                        }
                    }
                }
            }

            // External recipient warning
            if recipients.contains(where: { !$0.hasSuffix("@xqmsg.com") }) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(red: 1.000, green: 0.584, blue: 0.000))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("External Recipients Detected")
                            .font(.system(size: 13, weight: .semibold))
                        Text("AI risk analysis will run before sharing.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 1.000, green: 0.973, blue: 0.882))
                )
            }
        }
    }

    // MARK: - Step 2: AI Risk

    private var step2View: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Risk Analysis")
                    .font(.system(size: 19, weight: .bold))
                Text("Detected sensitive content")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)

            // PHI card
            RiskContentCard(
                icon: "❤️‍🩹",
                title: "PHI Detected",
                detail: "3 patient records, SSNs, DOBs",
                severity: .restricted
            )

            // Financial data card
            RiskContentCard(
                icon: "💰",
                title: "Financial Data",
                detail: "Revenue figures, cost projections",
                severity: .confidential
            )

            // Risk score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall Risk Score")
                        .font(.system(size: 13, weight: .semibold))
                    Text("External sharing will be audit-logged")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("87")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(red: 0.714, green: 0.110, blue: 0.110))
                Text("/ 100")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.988, green: 0.894, blue: 0.925))
            )
        }
    }

    // MARK: - Step 3: Settings

    private var step3View: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Share Settings")
                    .font(.system(size: 19, weight: .bold))
                Text("Configure access controls")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)

            VStack(spacing: 0) {
                ShareSettingRow(
                    icon: "clock",
                    title: "Expiry",
                    detail: "7 days",
                    isToggle: false
                )

                Divider().padding(.leading, 44)

                ToggleSettingRow(
                    icon: "camera.viewfinder",
                    title: "Screenshot Detection",
                    isOn: $screenshotDetection
                )

                Divider().padding(.leading, 44)

                ToggleSettingRow(
                    icon: "lock.shield",
                    title: "Require XQ App",
                    isOn: $requireXQApp
                )

                Divider().padding(.leading, 44)

                ToggleSettingRow(
                    icon: "list.clipboard",
                    title: "Audit Log",
                    isOn: $auditLog
                )
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Step 4: Confirmation

    private var step4View: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 16)

            ZStack {
                Circle()
                    .fill(Color(red: 0.890, green: 0.949, blue: 0.992))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(brandBlue)
            }

            VStack(spacing: 6) {
                Text("Shared Securely")
                    .font(.system(size: 22, weight: .bold))
                Text("End-to-end encrypted link created")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ConfirmationDetail(label: "Encryption", value: "AES-256-GCM")
                ConfirmationDetail(label: "Recipients", value: recipients.isEmpty ? "1 recipient" : "\(recipients.count) recipient\(recipients.count == 1 ? "" : "s")")
                ConfirmationDetail(label: "Expires", value: "7 days")
                ConfirmationDetail(label: "Audit", value: "Enabled")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )

            Button {
                isPresented = false
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(brandBlue))
            }

            Spacer(minLength: 8)
        }
    }
}

// MARK: - Sub-components

private struct RiskContentCard: View {
    let icon: String
    let title: String
    let detail: String
    let severity: SensitivityLevel

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            SensitivityBadge(sensitivity: severity)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct ShareSettingRow: View {
    let icon: String
    let title: String
    let detail: String
    let isToggle: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15))
            Spacer()
            Text(detail)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

private struct ToggleSettingRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(red: 0.204, green: 0.780, blue: 0.349))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct ConfirmationDetail: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
    }
}

#Preview {
    SecureShareSheet(isPresented: .constant(true))
        .presentationDetents([.large])
}
