import SwiftUI
import XQEmailIntelligence

struct PhishingAlertView: View {
    @Environment(\.dismiss) private var dismiss
    let risk: EmailRiskAssessment

    @State private var actionTaken: PhishingAction? = nil
    @State private var showConfirmation = false

    private let brandRed = Color(red: 0.9, green: 0.2, blue: 0.15)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    riskScoreCard
                    signalsSection
                    policySection
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Phishing Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Dismiss") { dismiss() }
                }
            }
            .alert(confirmationTitle, isPresented: $showConfirmation) {
                Button(confirmationLabel, role: actionTaken == .quarantine ? .destructive : nil) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { actionTaken = nil }
            } message: {
                Text(confirmationMessage)
            }
        }
    }

    // MARK: - Risk Score Card

    private var riskScoreCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(brandRed)
                VStack(alignment: .leading, spacing: 4) {
                    Text(risk.overallRisk.rawValue.capitalized + " Risk")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(brandRed)
                    Text("AI confidence: high")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(brandRed.opacity(0.2), lineWidth: 5)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(risk.riskScore) / 100)
                        .stroke(brandRed, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("\(risk.riskScore)")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(brandRed)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if risk.isPhishing         { RiskTag(label: "Phishing", color: .red) }
                    if risk.isBEC              { RiskTag(label: "BEC", color: .red) }
                    if risk.hasPromptInjection { RiskTag(label: "Prompt Injection", color: .purple) }
                    if risk.hasUrgencyManipulation { RiskTag(label: "Urgency", color: .orange) }
                    if risk.hasImpersonation   { RiskTag(label: "Impersonation", color: .orange) }
                    RiskTag(label: "Score: \(risk.riskScore)/100", color: brandRed)
                }
            }
        }
        .padding(16)
        .background(brandRed.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(brandRed.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Signals

    private var signalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Risk Signals")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            VStack(spacing: 0) {
                if risk.signals.isEmpty {
                    Text("No specific signals detected")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(16)
                } else {
                    ForEach(Array(risk.signals.enumerated()), id: \.offset) { idx, signal in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(riskColor(risk.overallRisk))
                                .frame(width: 20)
                                .padding(.top, 1)
                            Text(signal.description)
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        if idx < risk.signals.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Policy

    private var policySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Policy Controls")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            VStack(spacing: 0) {
                PolicyControlRow(icon: "shield.slash", label: "Block all links in message",
                                 enabled: risk.isPhishing)
                Divider().padding(.leading, 44)
                PolicyControlRow(icon: "exclamationmark.bubble", label: "Warn recipients on reply",
                                 enabled: risk.hasUrgencyManipulation)
                Divider().padding(.leading, 44)
                PolicyControlRow(icon: "person.badge.clock", label: "Flag sender for 30 days",
                                 enabled: risk.hasImpersonation)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                actionTaken = .quarantine
                showConfirmation = true
            } label: {
                Label("Quarantine Message", systemImage: "archivebox.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(brandRed))
            }

            Button {
                actionTaken = .report
                showConfirmation = true
            } label: {
                Label("Report to Security Team", systemImage: "flag.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(brandRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(brandRed, lineWidth: 1.5)
                    )
            }

            Button {
                actionTaken = .allow
                showConfirmation = true
            } label: {
                Text("Allow — Accept Risk")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Helpers

    private enum PhishingAction { case quarantine, report, allow }

    private var confirmationTitle: String {
        switch actionTaken {
        case .quarantine: return "Quarantine Message?"
        case .report:     return "Report to Security?"
        case .allow:      return "Accept Risk?"
        case nil:         return ""
        }
    }

    private var confirmationLabel: String {
        switch actionTaken {
        case .quarantine: return "Quarantine"
        case .report:     return "Send Report"
        case .allow:      return "Accept Risk"
        case nil:         return "OK"
        }
    }

    private var confirmationMessage: String {
        switch actionTaken {
        case .quarantine:
            return "The message will be moved to quarantine and the sender flagged."
        case .report:
            return "An anonymized report will be sent to your security team for review."
        case .allow:
            return "You accept responsibility for any risk associated with this message."
        case nil:
            return ""
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
}

// MARK: - Shared Sub-views

struct RiskTag: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

private struct PolicyControlRow: View {
    let icon: String
    let label: String
    let enabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(enabled ? .red : .secondary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14))
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(enabled ? .red : Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
