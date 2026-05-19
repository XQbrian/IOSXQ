import SwiftUI
import XQCore

struct ReceivedShareView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var coordinator: AppCoordinator
    let share: ReceivedShare

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    @State private var showDeclineAlert = false
    @State private var showFileViewer = false

    private var secureFile: SecureFile {
        SecureFile(
            id: UUID(),
            name: share.fileName,
            mimeType: mimeType(for: share.fileExt),
            sizeBytes: share.sizeBytes,
            sensitivity: share.sensitivity,
            encryptedKeyId: "rcv-\(share.id.uuidString.prefix(8))",
            sourceProvider: .xqVault,
            modifiedAt: share.expiresAt.addingTimeInterval(-7 * 86400),
            riskScore: nil
        )
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf":  return "application/pdf"
        case "xlsx": return "application/vnd.ms-excel"
        case "docx": return "application/msword"
        case "pptx": return "application/vnd.ms-powerpoint"
        case "txt":  return "text/plain"
        default:     return "application/octet-stream"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    fileCard
                    senderCard
                    accessDetailsCard
                    actionButtons
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Received Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Decline Share", isPresented: $showDeclineAlert) {
                Button("Decline", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Decline this share? You won't be able to access the file.")
            }
            .sheet(isPresented: $showFileViewer) {
                NavigationStack {
                    FileViewerView(file: secureFile)
                }
                .environmentObject(coordinator)
            }
        }
    }

    // MARK: - File Card

    private var fileCard: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(brandBlue.opacity(0.1))
                    .frame(width: 80, height: 80)
                Text(share.fileExt.uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(brandBlue)
            }
            Text(share.fileName)
                .font(.system(size: 18, weight: .semibold))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                SensitivityBadge(sensitivity: share.sensitivity)
                Text(share.fileSizeLabel)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Sender Card

    private var senderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Shared By")
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(brandBlue).frame(width: 44, height: 44)
                    Text(share.senderInitials)
                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(share.senderName).font(.system(size: 15, weight: .semibold))
                    Text(share.senderEmail).font(.system(size: 13)).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill").font(.system(size: 12)).foregroundColor(.green)
                    Text("Verified").font(.system(size: 12)).foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Access Details

    private var accessDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Access Details")
            VStack(spacing: 10) {
                ShareDetailRow(icon: "lock.fill",   label: "Encryption", value: "AES-256-GCM",     iconColor: .green)
                ShareDetailRow(icon: "clock",        label: "Expires",    value: share.expiryLabel, iconColor: expiryColor)
                ShareDetailRow(icon: "eye",          label: "Permissions",value: share.permissions, iconColor: brandBlue)
                ShareDetailRow(icon: "arrow.triangle.2.circlepath",
                               label: "Forwarding", value: "Not allowed", iconColor: .secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button { showFileViewer = true } label: {
                Label("Open File", systemImage: "doc.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(brandBlue))
            }
            Button { showDeclineAlert = true } label: {
                Text("Decline Share")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemBackground))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1))
                    )
            }
        }
    }

    private var expiryColor: Color {
        let days = Int(share.expiresAt.timeIntervalSinceNow / 86400)
        if days < 1 { return .red }
        if days < 3 { return .orange }
        return .secondary
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
    }
}

// MARK: - Supporting View

private struct ShareDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(iconColor)
                .frame(width: 20)
            Text(label).font(.system(size: 14)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium))
        }
    }
}

// MARK: - Model

struct ReceivedShare: Identifiable {
    let id = UUID()
    let fileName: String
    let fileExt: String
    let sensitivity: SensitivityLevel
    let sizeBytes: Int64
    let senderName: String
    let senderEmail: String
    let expiresAt: Date
    let permissions: String

    var fileSizeLabel: String {
        if sizeBytes < 1024      { return "\(sizeBytes) B" }
        if sizeBytes < 1_048_576 { return "\(sizeBytes / 1024) KB" }
        return String(format: "%.1f MB", Double(sizeBytes) / 1_048_576)
    }

    var senderInitials: String {
        senderName.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    var expiryLabel: String {
        let delta = expiresAt.timeIntervalSinceNow
        if delta < 0 { return "Expired" }
        let days = Int(delta / 86400)
        if days == 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }

    static let sample = ReceivedShare(
        fileName: "Patient-Records-2025.pdf",
        fileExt: "pdf",
        sensitivity: .restricted,
        sizeBytes: 1_048_576,
        senderName: "Sarah Chen",
        senderEmail: "sarah.chen@acmecorp.com",
        expiresAt: Date().addingTimeInterval(2 * 86400),
        permissions: "View only"
    )

    static let samples: [ReceivedShare] = [
        sample,
        ReceivedShare(
            fileName: "Q4-Financial-Report.xlsx",
            fileExt: "xlsx",
            sensitivity: .confidential,
            sizeBytes: 245_760,
            senderName: "Michael Torres",
            senderEmail: "m.torres@finance.com",
            expiresAt: Date().addingTimeInterval(5 * 86400),
            permissions: "View & download"
        )
    ]
}

#Preview {
    ReceivedShareView(share: .sample)
}
