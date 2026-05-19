import SwiftUI
import XQCore

struct DataLineageView: View {
    @Environment(\.dismiss) private var dismiss
    let file: SecureFile

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    private var events: [LineageEvent] { LineageEvent.mock(for: file) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    fileHeaderCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    Text("Provenance Timeline")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.5)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    timelineSection
                        .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Data Lineage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - File Header

    private var fileHeaderCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(brandBlue.opacity(0.1))
                    .frame(width: 52, height: 52)
                Text(fileExtension.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(brandBlue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    SensitivityBadge(sensitivity: file.sensitivity)
                    Text(file.sourceProvider.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(event.color.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: event.icon)
                                .font(.system(size: 15))
                                .foregroundColor(event.color)
                        }
                        if idx < events.count - 1 {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: 2, height: 32)
                        }
                    }
                    .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.title)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(event.timeLabel)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Text(event.description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let actor = event.actor {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(actor)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.bottom, idx < events.count - 1 ? 16 : 0)
                }
            }
        }
    }

    private var fileExtension: String {
        file.name.components(separatedBy: ".").last ?? "file"
    }
}

// MARK: - Model

struct LineageEvent {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let timeLabel: String
    let actor: String?

    static func mock(for file: SecureFile) -> [LineageEvent] {
        let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short

        return [
            LineageEvent(icon: "plus.circle.fill", color: brandBlue,
                         title: "File Created",
                         description: "Original document created in SharePoint",
                         timeLabel: df.string(from: file.modifiedAt.addingTimeInterval(-86400 * 30)),
                         actor: "Brian Wane"),
            LineageEvent(icon: "pencil.circle.fill", color: .blue,
                         title: "Modified",
                         description: "Content updated — 3 sections revised",
                         timeLabel: df.string(from: file.modifiedAt.addingTimeInterval(-86400 * 14)),
                         actor: "Sarah Chen"),
            LineageEvent(icon: "brain", color: .purple,
                         title: "AI Scan",
                         description: "On-device CoreML model scanned for sensitive entities",
                         timeLabel: df.string(from: file.modifiedAt.addingTimeInterval(-86400 * 7)),
                         actor: "XQ Agent"),
            LineageEvent(icon: "tag.fill", color: sensitivityColor(file.sensitivity),
                         title: "Classified",
                         description: "Sensitivity: \(file.sensitivity.rawValue.capitalized) — auto-applied by policy engine",
                         timeLabel: df.string(from: file.modifiedAt.addingTimeInterval(-86400 * 7)),
                         actor: "Policy Engine"),
            LineageEvent(icon: "lock.fill", color: Color(red: 0.204, green: 0.780, blue: 0.349),
                         title: "Encrypted",
                         description: "AES-256-GCM applied · Key anchored to Secure Enclave",
                         timeLabel: df.string(from: file.modifiedAt.addingTimeInterval(-86400 * 7)),
                         actor: nil),
            LineageEvent(icon: "arrow.up.forward.circle.fill", color: .orange,
                         title: "Shared",
                         description: "Encrypted share link created · Expiry: 7 days",
                         timeLabel: df.string(from: file.modifiedAt.addingTimeInterval(-86400 * 3)),
                         actor: "Brian Wane"),
            LineageEvent(icon: "eye.fill", color: Color(.secondaryLabel),
                         title: "Accessed",
                         description: "Viewed by authorized recipient",
                         timeLabel: df.string(from: file.modifiedAt),
                         actor: "Dr. Michael Torres"),
        ]
    }

    private static func sensitivityColor(_ level: SensitivityLevel) -> Color {
        switch level {
        case .public_:      return .green
        case .internal_:    return Color(red: 0.239, green: 0.353, blue: 0.996)
        case .confidential: return Color(red: 0.427, green: 0.298, blue: 0.000)
        case .restricted:   return Color(red: 0.482, green: 0.000, blue: 0.200)
        }
    }
}
