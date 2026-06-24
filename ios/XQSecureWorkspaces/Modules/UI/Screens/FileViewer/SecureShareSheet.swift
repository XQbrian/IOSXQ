import SwiftUI
import XQCore
import XQFileIntelligence
import XQPolicy

struct SecureShareSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var vm: SecureShareViewModel

    @State private var step = 1
    @State private var recipientEmail = ""
    @State private var recipients: [String] = []
    @State private var expiryDays = 7
    @State private var permissions = "View only"
    @State private var screenshotDetection = true
    @State private var requireXQApp = true
    @State private var auditLog = true

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let totalSteps = 4

    init(
        isPresented: Binding<Bool>,
        file: SecureFile,
        rawFileData: Data,
        classificationResult: AIClassificationResult?,
        session: XQSession,
        graphClient: MicrosoftGraphClient?,
        xqAPI: (any XQSecureAPI)? = nil
    ) {
        _isPresented = isPresented
        _vm = StateObject(wrappedValue: SecureShareViewModel(
            file: file,
            rawFileData: rawFileData,
            classificationResult: classificationResult,
            session: session,
            graphClient: graphClient,
            xqAPI: xqAPI
        ))
    }

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

            // Navigation / action button
            if step < totalSteps {
                VStack(spacing: 0) {
                    if let error = vm.sendError, step == 3 {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }

                    Button {
                        if step == 3 {
                            Task {
                                await vm.send(recipients: recipients, expiryDays: expiryDays)
                                if vm.sendSuccess { withAnimation { step = 4 } }
                            }
                        } else {
                            withAnimation { step += 1 }
                        }
                    } label: {
                        Group {
                            if step == 3 && vm.isSending {
                                ProgressView().tint(.white)
                            } else {
                                Text(step == 1 ? "Analyze Risk" : step == 2 ? "Configure Settings" : "Send Securely")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16).fill(brandBlue))
                    }
                    .disabled(step == 3 && vm.isSending)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 44)
                }
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
                            .background(Capsule().fill(Color(red: 0.910, green: 0.918, blue: 0.992)))
                        }
                    }
                }
            }

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
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 1.000, green: 0.973, blue: 0.882)))
            }
        }
    }

    // MARK: - Step 2: AI Risk

    private var step2View: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Risk Analysis")
                    .font(.system(size: 19, weight: .bold))
                Text("Sensitive content scan results")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)

            if let result = vm.classificationResult, !result.entities.isEmpty {
                let uniqueTypes = result.entities.map(\.type).reduce(into: [AIEntity.EntityType]()) { arr, t in
                    if !arr.contains(t) { arr.append(t) }
                }
                ForEach(uniqueTypes, id: \.self) { type in
                    let count = result.entities.filter { $0.type == type }.count
                    RiskContentCard(
                        icon: entityTypeEmoji(type),
                        title: entityTypeTitle(type) + " Detected",
                        detail: "\(count) instance\(count == 1 ? "" : "s") found",
                        severity: entityTypeSensitivity(type)
                    )
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Overall Risk Score")
                            .font(.system(size: 13, weight: .semibold))
                        Text("External sharing will be audit-logged")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(result.riskScore)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(riskScoreColor(result.riskScore))
                    Text("/ 100")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(riskScoreColor(result.riskScore).opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("No sensitive content detected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(14)
                .background(Color.green.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Overall Risk Score")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Audit logging enabled")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("0")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                    Text("/ 100")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.green.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
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
                StepperSettingRow(
                    icon: "clock",
                    title: "Expiry",
                    value: $expiryDays,
                    range: 1...30,
                    label: { "\($0) day\($0 == 1 ? "" : "s")" }
                )
                Divider().padding(.leading, 44)
                PermissionsPickerRow(selection: $permissions)
                Divider().padding(.leading, 44)
                ToggleSettingRow(icon: "camera.viewfinder", title: "Screenshot Detection", isOn: $screenshotDetection)
                Divider().padding(.leading, 44)
                ToggleSettingRow(icon: "lock.shield", title: "Require XQ App", isOn: $requireXQApp)
                Divider().padding(.leading, 44)
                ToggleSettingRow(icon: "list.clipboard", title: "Audit Log", isOn: $auditLog)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)

            if !vm.hasCloudUpload {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("File will be encrypted locally — connect a Microsoft account to upload and share a link automatically.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
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
                Text(vm.hasCloudUpload ? "Encrypted link created in OneDrive" : "File encrypted locally — AES-256-GCM")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ConfirmationDetail(label: "Encryption", value: "AES-256-GCM")
                ConfirmationDetail(
                    label: "Recipients",
                    value: recipients.isEmpty ? "No recipients" : "\(recipients.count) recipient\(recipients.count == 1 ? "" : "s")"
                )
                ConfirmationDetail(label: "Permissions", value: permissions)
                ConfirmationDetail(label: "Expires", value: "\(expiryDays) day\(expiryDays == 1 ? "" : "s")")
                ConfirmationDetail(label: "Audit", value: "Enabled")
                if let keyId = vm.keyId {
                    ConfirmationDetail(label: "Key ID", value: keyId + "…")
                }
                if let shareURL = vm.shareURL {
                    ConfirmationDetail(label: "Host", value: shareURL.host ?? shareURL.absoluteString)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            if let shareURL = vm.shareURL {
                Button {
                    UIPasteboard.general.string = shareURL.absoluteString
                } label: {
                    Label("Copy Share Link", systemImage: "doc.on.doc")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(brandBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 16).stroke(brandBlue, lineWidth: 1.5))
                }
            }

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

    // MARK: - Helpers

    private func entityTypeEmoji(_ type: AIEntity.EntityType) -> String {
        switch type {
        case .phi:        return "❤️‍🩹"
        case .pii:        return "👤"
        case .financial:  return "💰"
        case .credential: return "🔑"
        case .pciData:    return "💳"
        }
    }

    private func entityTypeTitle(_ type: AIEntity.EntityType) -> String {
        switch type {
        case .phi:        return "PHI"
        case .pii:        return "PII"
        case .financial:  return "Financial Data"
        case .credential: return "Credentials"
        case .pciData:    return "PCI Data"
        }
    }

    private func entityTypeSensitivity(_ type: AIEntity.EntityType) -> SensitivityLevel {
        switch type {
        case .phi, .pii:           return .restricted
        case .financial, .pciData: return .confidential
        case .credential:          return .confidential
        }
    }

    private func riskScoreColor(_ score: Int) -> Color {
        if score >= 75 { return Color(red: 0.714, green: 0.110, blue: 0.110) }
        if score >= 40 { return .orange }
        return .green
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
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

private struct StepperSettingRow: View {
    let icon: String
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: (Int) -> String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15))
            Spacer()
            Stepper(label(value), value: $value, in: range)
                .labelsHidden()
            Text(label(value))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(minWidth: 56, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct PermissionsPickerRow: View {
    @Binding var selection: String
    private let options = ["View only", "View & download", "Edit"]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 24)
            Text("Permissions")
                .font(.system(size: 15))
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
