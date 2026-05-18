import SwiftUI
import XQCore
import XQEmailIntelligence

struct EmailDetailView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm: EmailDetailViewModel

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    init(email: SecureEmail) {
        let provider = LocalEmailIntelligenceProvider()
        let store = LocalSenderProfileStore()
        let orchestrator = EmailIntelligenceOrchestrator(
            prioritizer: provider,
            threadProvider: provider,
            toneAnalyzer: provider,
            riskDetector: provider,
            profileStore: store
        )
        _vm = StateObject(wrappedValue: EmailDetailViewModel(email: email, orchestrator: orchestrator))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                Divider()

                if vm.isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Analyzing…")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    Divider()
                } else if let risk = vm.risk, risk.overallRisk != .safe {
                    riskSection(risk)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    Divider()
                }

                bodySection
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                if !vm.actions.isEmpty {
                    Divider()
                    actionsSection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                Divider()
                replySection
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SensitivityBadge(sensitivity: vm.email.sensitivity)
            }
        }
        .task {
            let graphClient = coordinator.graphToken.map { MicrosoftGraphClient(graphToken: $0) }
            async let analyzeTask: () = vm.analyze()
            async let bodyTask: () = vm.loadBody(graphClient: graphClient)
            _ = await (analyzeTask, bodyTask)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vm.email.subject)
                .font(.system(size: 20, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Circle()
                    .fill(brandBlue.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(vm.email.senderName.prefix(1).uppercased())
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(brandBlue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.email.senderName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(vm.email.senderEmail)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(relativeDate(vm.email.receivedAt))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if !vm.email.recipientEmails.isEmpty {
                Text("To: " + vm.email.recipientEmails.joined(separator: ", "))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if vm.email.hasAttachments {
                Label("Attachment", systemImage: "paperclip")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Risk

    @ViewBuilder
    private func riskSection(_ risk: EmailRiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: riskIcon(risk.overallRisk))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(riskColor(risk.overallRisk))
                Text("Security Assessment")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(risk.riskScore)/100")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(riskColor(risk.overallRisk))
            }

            FlowLayout(spacing: 6) {
                RiskChip(label: risk.overallRisk.rawValue.capitalized, color: riskColor(risk.overallRisk))
                if risk.isPhishing         { RiskChip(label: "Phishing", color: .red) }
                if risk.isBEC              { RiskChip(label: "BEC", color: .red) }
                if risk.hasPromptInjection { RiskChip(label: "Injection", color: .purple) }
                if risk.hasUrgencyManipulation { RiskChip(label: "Urgency", color: .orange) }
                if risk.hasImpersonation   { RiskChip(label: "Impersonation", color: .orange) }
            }

            ForEach(risk.signals.prefix(3)) { signal in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(riskColor(risk.overallRisk))
                        .padding(.top, 1)
                    Text(signal.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if risk.recommendedAction == .quarantine || risk.recommendedAction == .block {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill").font(.system(size: 12)).foregroundColor(.red)
                    Text("Recommended: \(risk.recommendedAction.rawValue.capitalized)")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.red)
                }
                .padding(.vertical, 7).padding(.horizontal, 12)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(riskColor(risk.overallRisk).opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Body

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Message")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)

            if vm.isLoadingBody {
                ProgressView().scaleEffect(0.8)
            } else {
                Text(vm.fullBody ?? vm.email.bodyPreview)
                    .font(.system(size: 15))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Action Items")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)

            ForEach(vm.actions) { action in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: actionIcon(action.type))
                        .font(.system(size: 13))
                        .foregroundColor(brandBlue)
                        .frame(width: 18)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.text)
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                        if let deadline = action.deadline {
                            Text("By " + deadlineString(deadline))
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                    Text(String(format: "%.0f%%", action.confidence * 100))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Reply

    private var replySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let reply = vm.suggestedReply {
                Text("Suggested Reply")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.4)
                Text(reply)
                    .font(.system(size: 14))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .fixedSize(horizontal: false, vertical: true)
            } else if vm.email.sensitivity != .restricted {
                Button {
                    Task { await vm.suggestReply() }
                } label: {
                    Group {
                        if vm.isSuggestingReply {
                            ProgressView().tint(.white)
                        } else {
                            Label("Suggest Reply", systemImage: "sparkles")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(brandBlue))
                }
                .disabled(vm.isSuggestingReply)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundColor(.secondary)
                    Text("AI reply drafting disabled for restricted content (HIPAA §164.502)")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let delta = Date().timeIntervalSince(date)
        if delta < 3600 { return "\(Int(delta / 60))m ago" }
        if delta < 86400 { return "\(Int(delta / 3600))h ago" }
        let df = DateFormatter()
        df.dateStyle = .short; df.timeStyle = .short
        return df.string(from: date)
    }

    private func deadlineString(_ date: Date) -> String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .none
        return df.string(from: date)
    }

    private func riskIcon(_ level: EmailRiskLevel) -> String {
        switch level {
        case .safe:     return "checkmark.shield"
        case .low:      return "shield"
        case .medium:   return "exclamationmark.shield"
        case .high:     return "xmark.shield.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private func riskColor(_ level: EmailRiskLevel) -> Color {
        switch level {
        case .safe:     return .green
        case .low:      return .blue
        case .medium:   return .orange
        case .high:     return Color(red: 0.9, green: 0.3, blue: 0.1)
        case .critical: return .red
        }
    }

    private func actionIcon(_ type: ExtractedEmailAction.ActionType) -> String {
        switch type {
        case .commitment:        return "checkmark.circle"
        case .request:           return "arrow.right.circle"
        case .approval:          return "hand.thumbsup"
        case .reminder:          return "bell"
        case .followUp:          return "arrow.clockwise"
        case .procurementAction: return "cart"
        case .legalReview:       return "doc.text.magnifyingglass"
        }
    }
}

// MARK: - Supporting views

private struct RiskChip: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, sz.height); x += sz.width + spacing
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            rowH = max(rowH, sz.height); x += sz.width + spacing
        }
    }
}
