import SwiftUI
import XQCore
import XQAI
import XQPolicy

struct AIImportView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = AIImportViewModel(
        aiOrchestrator: StubImportAIOrchestrator(),
        policyEngine: StubImportPolicyEngine()
    )

    @State private var scanBarOffset: CGFloat = 0
    @State private var animating = false

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    private let sourceOptions: [(icon: String, title: String, subtitle: String)] = [
        ("📁", "Files App", "Browse device & iCloud"),
        ("📷", "Camera", "Scan physical document"),
        ("☁️", "iCloud Drive", "Select from iCloud"),
        ("📡", "AirDrop", "Receive from nearby device")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Source selection grid
                    if !vm.isScanning && !vm.scanComplete {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose Source")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .kerning(0.5)
                                .padding(.horizontal, 20)

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ],
                                spacing: 12
                            ) {
                                ForEach(sourceOptions, id: \.title) { option in
                                    SourceCard(
                                        icon: option.icon,
                                        title: option.title,
                                        subtitle: option.subtitle
                                    ) {
                                        vm.startScan()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Scan animation
                    if vm.isScanning {
                        VStack(spacing: 14) {
                            ScanAnimationBox(isAnimating: vm.isScanning)

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(vm.scanSteps, id: \.self) { stepText in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(red: 0.204, green: 0.780, blue: 0.349))
                                        Text(stepText)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                                if let last = vm.scanSteps.last, last != vm.scanSteps.last {
                                    // processing indicator for current step
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                            .animation(.easeInOut, value: vm.scanSteps.count)
                        }
                    }

                    // Scan complete result
                    if vm.scanComplete, let result = vm.result {
                        VStack(spacing: 14) {
                            ResultCard(result: result)
                                .padding(.horizontal, 16)

                            Button {
                                // Encrypt and save action
                            } label: {
                                Label("Encrypt & Save to Vault", systemImage: "lock.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(brandBlue))
                            }
                            .padding(.horizontal, 16)

                            Button {
                                vm.startScan()
                            } label: {
                                Text("Reclassify")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(brandBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(brandBlue, lineWidth: 1.5)
                                    )
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Import & Classify")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        coordinator.navigate(to: .home)
                    }
                    .foregroundColor(brandBlue)
                }
            }
        }
    }
}

// MARK: - Sub-views

private struct SourceCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(icon)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct ScanAnimationBox: View {
    let isAnimating: Bool

    @State private var gradientOffset: CGFloat = -1.0

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        ZStack {
            Color.black

            // Grid overlay
            Canvas { context, size in
                let spacing: CGFloat = 20
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(path, with: .color(brandBlue.opacity(0.15)), lineWidth: 1)
            }

            // Animated scan bar
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, brandBlue, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 3)
                .offset(y: isAnimating ? geo.size.height : 0)
                .animation(
                    isAnimating
                        ? .linear(duration: 1.4).repeatForever(autoreverses: false)
                        : .default,
                    value: isAnimating
                )
            }

            VStack(spacing: 8) {
                Text("AI Scanning…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("On-device CoreML · No cloud")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

private struct ResultCard: View {
    let result: AIClassificationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Classification Result")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                SensitivityBadge(sensitivity: result.sensitivity)
            }

            Divider()

            HStack(spacing: 0) {
                ResultStat(label: "Risk Score", value: "\(result.riskScore)")
                Divider().frame(height: 32)
                ResultStat(label: "Entities", value: "\(result.entities.count)")
                Divider().frame(height: 32)
                ResultStat(label: "Model", value: result.wasCloudProcessed ? "Cloud" : "Local")
            }

            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(result.modelVersion)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(result.processingMs)ms")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}

private struct ResultStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stubs

private final class StubImportAIOrchestrator: AIOrchestrator {
    func provider(for sensitivity: SensitivityLevel, policy: PolicyBundle) -> any AIProvider {
        StubImportAIProvider()
    }
    func scanAndClassify(fileData: Data, mimeType: String, policy: PolicyBundle) async throws -> AIClassificationResult {
        AIClassificationResult(fileId: UUID(), sensitivity: .restricted, riskScore: 87, entities: [], modelVersion: "CoreML-3.1", processingMs: 2340, wasCloudProcessed: false)
    }
}

private final class StubImportAIProvider: AIProvider {
    var isLocalOnly: Bool { true }
    func classify(fileData: Data, mimeType: String, policy: PolicyBundle) async throws -> AIClassificationResult {
        AIClassificationResult(fileId: UUID(), sensitivity: .restricted, riskScore: 87, entities: [], modelVersion: "CoreML-3.1", processingMs: 2340, wasCloudProcessed: false)
    }
    func extractEntities(from text: String, policy: PolicyBundle) async throws -> [AIEntity] { [] }
    func scoreRisk(file: SecureFile, entities: [AIEntity], policy: PolicyBundle) async throws -> Int { 87 }
}

private final class StubImportPolicyEngine: PolicyEngine {
    var currentBundle: PolicyBundle? { nil }
    func loadBundle(_ bundle: PolicyBundle) async throws {}
    func evaluate(operation: PolicyOperation, for file: SecureFile, actor: String) async -> PolicyDecision {
        PolicyDecision(allowed: true, enforcement: .audit, citedControls: [], requiredApprovalRole: nil, auditRequired: false)
    }
    func rule(for sensitivity: SensitivityLevel) -> PolicyRule? { nil }
}

#Preview {
    AIImportView()
        .environmentObject(AppCoordinator())
}
