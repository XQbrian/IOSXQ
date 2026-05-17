import SwiftUI

struct FileViewerView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm: FileViewerViewModel

    @State private var showShareSheet = false

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    init(file: SecureFile) {
        _vm = StateObject(wrappedValue: FileViewerViewModel(
            file: file,
            aiOrchestrator: StubAIOrchestrator(),
            policyEngine: StubFileViewerPolicyEngine(),
            xqAPI: StubXQSecureAPI()
        ))
    }

    // MARK: - Classification Banner

    private var bannerBackground: Color {
        switch vm.file.sensitivity {
        case .restricted: return Color(red: 0.482, green: 0.000, blue: 0.200)
        case .confidential: return Color(red: 0.427, green: 0.298, blue: 0.000)
        case .internal_: return Color(red: 0.051, green: 0.278, blue: 0.631)
        case .public_: return Color(red: 0.106, green: 0.369, blue: 0.125)
        }
    }

    private var bannerText: String {
        switch vm.file.sensitivity {
        case .restricted: return "RESTRICTED — PHI DETECTED"
        case .confidential: return "CONFIDENTIAL — INTERNAL USE ONLY"
        case .internal_: return "INTERNAL — DO NOT DISTRIBUTE"
        case .public_: return "PUBLIC"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Classification banner
            HStack(spacing: 10) {
                Text(bannerText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .kerning(0.5)

                Spacer()

                Text("AI Classified")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.20))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(bannerBackground)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Document body area
                    ZStack {
                        Color(UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0))

                        // Watermark
                        Text("RESTRICTED · brian@xqmsg.com")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(Color(red: 0.482, green: 0.000, blue: 0.200))
                            .opacity(0.07)
                            .rotationEffect(.degrees(-30))
                            .lineLimit(1)
                            .fixedSize()

                        VStack(alignment: .leading, spacing: 12) {
                            // Placeholder document blocks
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: i == 0 ? 60 : i == 1 ? 100 : 80)
                            }
                        }
                        .padding(20)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)

                    // Cited Controls
                    if let result = vm.classificationResult, !vm.citedControls.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cited Controls Triggered")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color(red: 0.482, green: 0.000, blue: 0.200))
                                .padding(.horizontal, 16)

                            VStack(spacing: 10) {
                                ForEach(Array(vm.citedControls.enumerated()), id: \.offset) { _, control in
                                    CitedControlCard(control: control)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 4)
                        .id(result.fileId)
                    }

                    Spacer(minLength: 120)
                }
                .padding(.top, 16)
            }

            // Bottom fixed panel
            BottomPanel(vm: vm, onShare: { showShareSheet = true })
        }
        .navigationTitle(vm.file.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(brandBlue)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            SecureShareSheet(isPresented: $showShareSheet)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .task {
            let stubSession = XQSession(
                userId: "brian@xqmsg.com",
                tenantId: "acme-corp",
                accessToken: "",
                expiresAt: Date().addingTimeInterval(3600),
                apiVersion: .v3
            )
            await vm.loadAndScan(session: stubSession)
        }
    }
}

// MARK: - Cited Control Card

private struct CitedControlCard: View {
    let control: CitedControl

    private var frameworkColor: Color {
        switch control.framework {
        case .hipaa: return Color(red: 0.714, green: 0.110, blue: 0.110)
        case .nistSP80053: return Color(red: 0.051, green: 0.278, blue: 0.631)
        case .gdpr: return Color(red: 0.106, green: 0.369, blue: 0.125)
        case .xqPolicy: return Color(red: 0.239, green: 0.353, blue: 0.996)
        }
    }

    private var frameworkLabel: String {
        switch control.framework {
        case .hipaa: return "HIPAA"
        case .nistSP80053: return "NIST SP 800-53"
        case .gdpr: return "GDPR"
        case .xqPolicy: return "XQ Policy"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(frameworkColor)
                .frame(width: 4)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 12,
                        bottomLeadingRadius: 12,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(frameworkLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(frameworkColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(frameworkColor.opacity(0.12))
                        )

                    Text(control.controlId)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }

                Text(control.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(control.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Bottom Panel

private struct BottomPanel: View {
    @ObservedObject var vm: FileViewerViewModel
    let onShare: () -> Void

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    private var riskScore: Int {
        vm.classificationResult?.riskScore ?? vm.file.riskScore ?? 0
    }

    private var entityCount: Int {
        vm.classificationResult?.entities.count ?? 0
    }

    private var policyAllowed: Bool {
        vm.policyDecision?.allowed ?? true
    }

    var body: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 0) {
                StatCell(label: "Risk Score", value: "\(riskScore)")
                Divider().frame(height: 32)
                StatCell(label: "Entities", value: "\(entityCount)")
                Divider().frame(height: 32)
                StatCell(
                    label: "Policy",
                    value: policyAllowed ? "ALLOW" : "BLOCK",
                    valueColor: policyAllowed ? Color(red: 0.204, green: 0.780, blue: 0.349) : Color(red: 0.714, green: 0.110, blue: 0.110)
                )
            }
            .padding(.horizontal, 16)

            Button(action: onShare) {
                Label("Share Securely", systemImage: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(policyAllowed ? brandBlue : Color.gray)
                    )
            }
            .disabled(!policyAllowed)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }
}

private struct StatCell: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(valueColor)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stubs

private final class StubAIOrchestrator: AIOrchestrator {
    func provider(for sensitivity: SensitivityLevel, policy: PolicyBundle) -> any AIProvider {
        StubAIProvider()
    }
    func scanAndClassify(fileData: Data, mimeType: String, policy: PolicyBundle) async throws -> AIClassificationResult {
        AIClassificationResult(
            fileId: UUID(),
            sensitivity: .restricted,
            riskScore: 87,
            entities: [],
            modelVersion: "CoreML-3.0",
            processingMs: 340,
            wasCloudProcessed: false
        )
    }
}

private final class StubAIProvider: AIProvider {
    var isLocalOnly: Bool { true }
    func classify(fileData: Data, mimeType: String, policy: PolicyBundle) async throws -> AIClassificationResult {
        AIClassificationResult(fileId: UUID(), sensitivity: .restricted, riskScore: 87, entities: [], modelVersion: "CoreML-3.0", processingMs: 340, wasCloudProcessed: false)
    }
    func extractEntities(from text: String, policy: PolicyBundle) async throws -> [AIEntity] { [] }
    func scoreRisk(file: SecureFile, entities: [AIEntity], policy: PolicyBundle) async throws -> Int { 87 }
}

private final class StubFileViewerPolicyEngine: PolicyEngine {
    var currentBundle: PolicyBundle? { nil }
    func loadBundle(_ bundle: PolicyBundle) async throws {}
    func evaluate(operation: PolicyOperation, for file: SecureFile, actor: String) async -> PolicyDecision {
        PolicyDecision(allowed: false, enforcement: .block, citedControls: [], requiredApprovalRole: nil, auditRequired: true)
    }
    func rule(for sensitivity: SensitivityLevel) -> PolicyRule? { nil }
}

private final class StubXQSecureAPI: XQSecureAPI {
    var negotiatedVersion: XQAPIVersion { .v3 }
    func authenticate(credentials: XQCredentials) async throws -> XQSession {
        throw XQAPIError.unauthenticated
    }
    func refreshSession(_ session: XQSession) async throws -> XQSession { session }
    func revokeSession(_ session: XQSession) async throws {}
    func encryptFile(data: Data, session: XQSession) async throws -> EncryptedPayload {
        EncryptedPayload(ciphertext: data, iv: Data(), authTag: Data(), keyId: "stub")
    }
    func decryptFile(_ payload: EncryptedPayload, session: XQSession) async throws -> Data { Data() }
    func rotateFileKey(fileId: String, session: XQSession) async throws -> EncryptedPayload {
        EncryptedPayload(ciphertext: Data(), iv: Data(), authTag: Data(), keyId: fileId)
    }
    func fetchPolicyBundle(tenantId: String, session: XQSession) async throws -> PolicyBundle {
        throw XQAPIError.unauthenticated
    }
    func submitAuditEvent(_ event: AuditEvent, session: XQSession) async throws {}
}

#Preview {
    NavigationStack {
        FileViewerView(file: SecureFile(
            id: UUID(),
            name: "Q4-Financial-Report.pdf",
            mimeType: "application/pdf",
            sizeBytes: 2_519_040,
            sensitivity: .restricted,
            encryptedKeyId: "key-001",
            sourceProvider: .sharePoint,
            modifiedAt: Date(),
            riskScore: 87
        ))
    }
    .environmentObject(AppCoordinator())
}
