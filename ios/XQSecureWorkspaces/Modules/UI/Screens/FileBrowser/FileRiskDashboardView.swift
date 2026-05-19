import SwiftUI
import XQCore

struct FileRiskDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var coordinator: AppCoordinator

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let orgRiskScore = 73

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    orgRiskCard
                    riskBreakdownSection
                    filesAtRiskSection
                    agentCTASection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .navigationTitle("File Risk Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Org Risk Card

    private var orgRiskCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 88, height: 88)
                Circle()
                    .trim(from: 0, to: CGFloat(orgRiskScore) / 100)
                    .stroke(riskColor(orgRiskScore), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(orgRiskScore)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(riskColor(orgRiskScore))
                    Text("/100")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Org Risk Score")
                    .font(.system(size: 18, weight: .bold))
                Text("High risk — immediate review recommended")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                    Text("+12 pts since last scan")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Risk Breakdown

    private var riskBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Risk Breakdown")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            VStack(spacing: 12) {
                RiskBar(label: "Credential Exposure", value: 0.82, count: 4, color: .red)
                RiskBar(label: "Stale Permissions", value: 0.61, count: 11, color: .orange)
                RiskBar(label: "Unencrypted Shares", value: 0.44, count: 3,
                        color: Color(red: 0.9, green: 0.7, blue: 0))
                RiskBar(label: "Overdue Expiry", value: 0.28, count: 2, color: brandBlue)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Files At Risk

    private var filesAtRiskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Files at Risk")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            VStack(spacing: 0) {
                ForEach(RiskyFile.samples) { file in
                    Button {
                        dismiss()
                        coordinator.selectedTab = .files
                    } label: {
                        RiskyFileRow(file: file)
                    }
                    .buttonStyle(.plain)
                    if file.id != RiskyFile.samples.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Agent CTA

    private var agentCTASection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "brain")
                    .font(.system(size: 18))
                    .foregroundColor(brandBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Autonomous Risk Remediation")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Let XQ Agent review and remediate all flagged files automatically.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(brandBlue.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                dismiss()
                coordinator.navigate(to: .aiImport)
            } label: {
                Label("Run AI Remediation", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(brandBlue))
            }
        }
    }

    private func riskColor(_ score: Int) -> Color {
        if score >= 75 { return .red }
        if score >= 50 { return .orange }
        if score >= 25 { return Color(red: 0.9, green: 0.7, blue: 0) }
        return .green
    }
}

// MARK: - Sub-views

private struct RiskBar: View {
    let label: String
    let value: Double
    let count: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 13))
                Spacer()
                Text("\(count) file\(count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * value, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct RiskyFileRow: View {
    let file: RiskyFile

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(file.riskColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: file.riskIcon)
                    .font(.system(size: 16))
                    .foregroundColor(file.riskColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(file.riskReason)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Score: \(file.score)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(file.riskColor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Mock Model

private struct RiskyFile: Identifiable {
    let id = UUID()
    let name: String
    let score: Int
    let riskReason: String
    let riskIcon: String
    let riskColor: Color

    static let samples: [RiskyFile] = [
        RiskyFile(name: "credentials-backup.txt", score: 96,
                  riskReason: "Contains plain-text credentials",
                  riskIcon: "key.fill", riskColor: .red),
        RiskyFile(name: "Patient-Records-2025.pdf", score: 88,
                  riskReason: "PHI data — external share pending",
                  riskIcon: "cross.fill", riskColor: .red),
        RiskyFile(name: "board-strategy-2026.pptx", score: 71,
                  riskReason: "Stale permissions — 14 former employees",
                  riskIcon: "person.slash", riskColor: .orange),
        RiskyFile(name: "Q4-Financial-Report.xlsx", score: 64,
                  riskReason: "Share link expired 2 days ago",
                  riskIcon: "clock.badge.exclamationmark", riskColor: .orange),
    ]
}
