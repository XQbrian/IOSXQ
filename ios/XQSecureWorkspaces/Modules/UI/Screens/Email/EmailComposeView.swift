import SwiftUI
import XQCore
import XQEmailIntelligence

// MARK: - Compose Config

struct ComposeConfig {
    var toAddresses: [String] = []
    var ccAddresses: [String] = []
    var bccAddresses: [String] = []
    var subject: String = ""
    var quotedBody: String = ""
    var title: String = "New Message"

    static func reply(to email: SecureEmail) -> ComposeConfig {
        ComposeConfig(
            toAddresses: [email.senderEmail],
            subject: email.subject.hasPrefix("Re: ") ? email.subject : "Re: " + email.subject,
            quotedBody: quotedBlock(email),
            title: "Reply"
        )
    }

    static func replyAll(to email: SecureEmail, myEmail: String) -> ComposeConfig {
        let cc = email.recipientEmails.filter { $0 != myEmail }
        return ComposeConfig(
            toAddresses: [email.senderEmail],
            ccAddresses: cc,
            subject: email.subject.hasPrefix("Re: ") ? email.subject : "Re: " + email.subject,
            quotedBody: quotedBlock(email),
            title: "Reply All"
        )
    }

    static func forward(email: SecureEmail) -> ComposeConfig {
        ComposeConfig(
            subject: email.subject.hasPrefix("Fwd: ") ? email.subject : "Fwd: " + email.subject,
            quotedBody: forwardBlock(email),
            title: "Forward"
        )
    }

    private static func quotedBlock(_ email: SecureEmail) -> String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        return "\n\n\n—— On \(df.string(from: email.receivedAt)), \(email.senderName) <\(email.senderEmail)> wrote:\n\n\(email.bodyPreview)"
    }

    private static func forwardBlock(_ email: SecureEmail) -> String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        return "\n\n\n—— Forwarded message ——\nFrom: \(email.senderName) <\(email.senderEmail)>\nDate: \(df.string(from: email.receivedAt))\nSubject: \(email.subject)\n\n\(email.bodyPreview)"
    }
}

// MARK: - EmailComposeView

struct EmailComposeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var toField: String
    @State private var ccField: String
    @State private var bccField: String
    @State private var subjectField: String
    @State private var bodyText: String
    @State private var showCCBCC: Bool
    @State private var sensitivity: SensitivityLevel = .internal_
    @State private var showDiscardAlert = false

    private let navTitle: String
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private var tone: ComposeTone { ComposeTone.analyze(body: bodyText) }

    // New message
    init() {
        _toField = State(initialValue: "")
        _ccField = State(initialValue: "")
        _bccField = State(initialValue: "")
        _subjectField = State(initialValue: "")
        _bodyText = State(initialValue: "")
        _showCCBCC = State(initialValue: false)
        navTitle = "New Message"
    }

    // Reply / Reply All / Forward
    init(config: ComposeConfig) {
        _toField = State(initialValue: config.toAddresses.joined(separator: ", "))
        _ccField = State(initialValue: config.ccAddresses.joined(separator: ", "))
        _bccField = State(initialValue: config.bccAddresses.joined(separator: ", "))
        _subjectField = State(initialValue: config.subject)
        _bodyText = State(initialValue: config.quotedBody)
        _showCCBCC = State(initialValue: !config.ccAddresses.isEmpty || !config.bccAddresses.isEmpty)
        navTitle = config.title
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                classificationBanner
                ScrollView {
                    VStack(spacing: 0) {
                        composeFields
                        Divider()
                        toneAnalysisBar
                        Divider()
                        bodyEditor
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showDiscardAlert = true }
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "paperplane.fill")
                            Text("Send")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(brandBlue))
                    }
                }
            }
            .alert("Discard Message?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
    }

    // MARK: - Classification Banner

    private var classificationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.system(size: 10))
            Text(sensitivity.composeBannerLabel)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
            Spacer()
            Menu {
                ForEach(SensitivityLevel.allCases, id: \.self) { level in
                    Button(level.rawValue.capitalized) { sensitivity = level }
                }
            } label: {
                HStack(spacing: 3) {
                    Text("Change").font(.system(size: 11))
                    Image(systemName: "chevron.down").font(.system(size: 9))
                }
            }
            .foregroundColor(.white)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(sensitivity.composebannerBg)
    }

    // MARK: - Compose Fields

    private var composeFields: some View {
        VStack(spacing: 0) {
            ComposeFieldRow(label: "To", text: $toField, placeholder: "Recipients")
            Divider().padding(.leading, 52)

            if showCCBCC {
                ComposeFieldRow(label: "CC", text: $ccField, placeholder: "")
                Divider().padding(.leading, 52)
                ComposeFieldRow(label: "BCC", text: $bccField, placeholder: "")
                Divider().padding(.leading, 52)
            }

            ComposeFieldRow(label: "Subject", text: $subjectField, placeholder: "Subject")
            Divider().padding(.leading, 52)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showCCBCC.toggle() }
            } label: {
                HStack {
                    Text(showCCBCC ? "Hide CC/BCC" : "Add CC/BCC")
                        .font(.system(size: 13))
                        .foregroundColor(brandBlue)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Tone Analysis Bar

    private var toneAnalysisBar: some View {
        HStack(spacing: 0) {
            toneCell(label: "Tone",
                     value: bodyText.isEmpty ? "—" : tone.label,
                     color: bodyText.isEmpty ? .secondary : tone.color)
            Divider().frame(height: 36)
            toneCell(label: "Commitments",
                     value: bodyText.isEmpty ? "—" : "\(tone.commitmentCount) found",
                     color: bodyText.isEmpty ? .secondary : (tone.commitmentCount > 0 ? .orange : .secondary))
            Divider().frame(height: 36)
            toneCell(label: "Classification",
                     value: sensitivity.rawValue.capitalized,
                     color: brandBlue)
        }
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private func toneCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Body Editor

    private var bodyEditor: some View {
        ZStack(alignment: .topLeading) {
            if bodyText.isEmpty {
                Text("Write your message…")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.tertiaryLabel))
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }
            TextEditor(text: $bodyText)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 12)
                .frame(minHeight: 300)
        }
    }
}

// MARK: - Compose Field Row

private struct ComposeFieldRow: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .leading)
                .padding(.leading, 16)
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .padding(.vertical, 12)
                .padding(.trailing, 16)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}

// MARK: - Tone Model

private struct ComposeTone {
    let label: String
    let color: Color
    let commitmentCount: Int

    static func analyze(body: String) -> ComposeTone {
        let lower = body.lowercased()
        let urgentWords = ["urgent", "asap", "immediately", "critical", "emergency"]
        let casualWords  = ["hey", "thanks", "hi", "btw", "fyi"]
        let commitWords  = ["will", "commit", "ensure", "guarantee", "promise", "by", "deadline"]

        let urgentScore = urgentWords.filter { lower.contains($0) }.count
        let casualScore = casualWords.filter  { lower.contains($0) }.count
        let commitCount = commitWords.filter  { lower.contains($0) }.count

        if urgentScore > 0 {
            return ComposeTone(label: "Urgent", color: .red, commitmentCount: commitCount)
        } else if casualScore > 0 {
            return ComposeTone(label: "Casual", color: .blue, commitmentCount: commitCount)
        } else {
            return ComposeTone(label: "Professional",
                               color: Color(red: 0.204, green: 0.780, blue: 0.349),
                               commitmentCount: commitCount)
        }
    }
}

// MARK: - SensitivityLevel compose helpers

private extension SensitivityLevel {
    var composeBannerLabel: String {
        switch self {
        case .public_:      return "PUBLIC"
        case .internal_:    return "INTERNAL — DO NOT DISTRIBUTE"
        case .confidential: return "CONFIDENTIAL — INTERNAL USE ONLY"
        case .restricted:   return "RESTRICTED — PHI DETECTED"
        }
    }
    var composebannerBg: Color {
        switch self {
        case .public_:      return Color(red: 0.106, green: 0.369, blue: 0.125)
        case .internal_:    return Color(red: 0.051, green: 0.278, blue: 0.631)
        case .confidential: return Color(red: 0.427, green: 0.298, blue: 0.000)
        case .restricted:   return Color(red: 0.482, green: 0.000, blue: 0.200)
        }
    }
}

#Preview {
    EmailComposeView()
}
