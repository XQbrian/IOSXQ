import SwiftUI
import XQCore
import XQFileIntelligence
import XQPolicy

struct FileViewerView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm: FileViewerViewModel

    @State private var showShareSheet = false
    @State private var showQuickLook = false
    @State private var showDataLineage = false
    @State private var showDocumentEditor = false

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    init(file: SecureFile) {
        _vm = StateObject(wrappedValue: FileViewerViewModel(
            file: file,
            aiOrchestrator: OnDeviceAIOrchestrator(),
            policyEngine: StubFileViewerPolicyEngine(),
            xqAPI: StubXQSecureAPI()
        ))
    }

    private var shareSession: XQSession {
        coordinator.currentSession ?? XQSession(
            userId: "local-user",
            tenantId: "local",
            accessToken: "",
            expiresAt: Date(timeIntervalSinceNow: 3600),
            apiVersion: .v3
        )
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
                    documentPreviewSection

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

                    // Detected Entities (AI scan output)
                    if let entities = vm.classificationResult?.entities, !entities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Detected Entities")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)

                            VStack(spacing: 8) {
                                ForEach(entities) { entity in
                                    EntityRow(entity: entity)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 4)
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
                HStack(spacing: 4) {
                    Button {
                        showDocumentEditor = true
                    } label: {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 16))
                            .foregroundColor(brandBlue)
                    }
                    Button {
                        showDataLineage = true
                    } label: {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 16))
                            .foregroundColor(brandBlue)
                    }
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(brandBlue)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            SecureShareSheet(
                isPresented: $showShareSheet,
                file: vm.file,
                rawFileData: vm.decryptedPreviewData ?? Data(),
                classificationResult: vm.classificationResult,
                session: shareSession,
                graphClient: coordinator.graphToken.map { MicrosoftGraphClient(graphToken: $0) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showDataLineage) {
            DataLineageView(file: vm.file)
        }
        .sheet(isPresented: $showDocumentEditor) {
            DocumentEditorView(file: vm.file)
        }
        .fullScreenCover(isPresented: $showQuickLook) {
            if let url = vm.quickLookURL {
                QuickLookPreview(url: url)
                    .ignoresSafeArea()
            }
        }
        .task {
            guard let session = coordinator.currentSession else { return }
            await vm.loadAndScan(session: session, repository: coordinator.repository)
        }
    }

    // MARK: - Document Preview Section

    @ViewBuilder
    private var documentPreviewSection: some View {
        Group {
            if vm.quickLookURL != nil {
                // Real file bytes are available — overlay a View button on the metadata card.
                ZStack(alignment: .bottom) {
                    genericDocumentPreview
                    Button {
                        showQuickLook = true
                    } label: {
                        Label("View Document", systemImage: "doc.viewfinder.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(brandBlue)
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 18)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            } else if let pdfData = vm.generatedPDFData, !pdfData.isEmpty {
                ZStack {
                    PDFDocumentView(data: pdfData)
                        .frame(maxWidth: .infinity)
                        .frame(height: 480)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("\(vm.file.sensitivity.rawValue) · brian@xqmsg.com")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(bannerBackground.opacity(0.08))
                        .rotationEffect(.degrees(-30))
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 16)
                .transition(.opacity)
            } else if vm.isScanning {
                scanningPlaceholder
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            } else {
                genericDocumentPreview
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.quickLookURL != nil)
        .animation(.easeInOut(duration: 0.25), value: vm.generatedPDFData)
        .animation(.easeInOut(duration: 0.25), value: vm.isScanning)
    }

    private var scanningPlaceholder: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.1)

            VStack(spacing: 4) {
                Text("Scanning document…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("On-device AI · CoreML 3.2")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 480)
        .background(Color(UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var genericDocumentPreview: some View {
        let (iconName, accent) = officeIconAndAccent(for: vm.file.mimeType)
        return VStack(spacing: 0) {
            // Top — large file-format glyph and filename
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(accent.opacity(0.18))
                        .frame(width: 88, height: 88)
                    Image(systemName: iconName)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(accent)
                }

                VStack(spacing: 4) {
                    Text(vm.file.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(formatLabel(for: vm.file.mimeType))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accent)
                        .kerning(0.5)
                }
            }
            .padding(.top, 36)
            .padding(.horizontal, 24)

            Spacer(minLength: 18)

            // Bottom — metadata grid
            VStack(spacing: 0) {
                metaRow(label: "Size", value: byteString(vm.file.sizeBytes))
                Divider().background(Color.white.opacity(0.08))
                metaRow(label: "Source", value: vm.file.sourceProvider.rawValue)
                Divider().background(Color.white.opacity(0.08))
                metaRow(label: "Modified", value: relativeDate(vm.file.modifiedAt))
                Divider().background(Color.white.opacity(0.08))
                metaRow(
                    label: "Encryption",
                    value: "AES-256-GCM",
                    valueColor: Color(red: 0.204, green: 0.780, blue: 0.349)
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 480)
        .background(Color(UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            // Diagonal watermark over the card.
            Text("\(vm.file.sensitivity.rawValue) · brian@xqmsg.com")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(bannerBackground.opacity(0.08))
                .rotationEffect(.degrees(-30))
                .allowsHitTesting(false)
        )
    }

    private func metaRow(label: String, value: String, valueColor: Color = .white) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 9)
    }

    private func officeIconAndAccent(for mime: String) -> (String, Color) {
        switch mime {
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return ("doc.text.fill", Color(red: 0.16, green: 0.42, blue: 0.85))
        case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
            return ("tablecells.fill", Color(red: 0.13, green: 0.62, blue: 0.31))
        case "application/vnd.openxmlformats-officedocument.presentationml.presentation":
            return ("rectangle.on.rectangle.fill", Color(red: 0.86, green: 0.43, blue: 0.13))
        case "application/pdf":
            return ("doc.richtext.fill", Color(red: 0.85, green: 0.15, blue: 0.15))
        default:
            return ("doc.fill", Color.gray)
        }
    }

    private func formatLabel(for mime: String) -> String {
        switch mime {
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return "MICROSOFT WORD · DOCX"
        case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
            return "MICROSOFT EXCEL · XLSX"
        case "application/vnd.openxmlformats-officedocument.presentationml.presentation":
            return "MICROSOFT POWERPOINT · PPTX"
        case "application/pdf":
            return "PORTABLE DOCUMENT · PDF"
        default:
            return mime.uppercased()
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Entity Row

private struct EntityRow: View {
    let entity: AIEntity

    private var iconName: String {
        switch entity.type {
        case .phi: return "cross.case.fill"
        case .pii: return "person.text.rectangle.fill"
        case .financial: return "dollarsign.circle.fill"
        case .credential: return "key.fill"
        case .pciData: return "creditcard.fill"
        }
    }

    private var iconColor: Color {
        switch entity.type {
        case .phi: return Color(red: 0.78, green: 0.12, blue: 0.30)
        case .pii: return Color(red: 0.62, green: 0.30, blue: 0.78)
        case .financial: return Color(red: 0.17, green: 0.58, blue: 0.30)
        case .credential: return Color(red: 0.86, green: 0.55, blue: 0.10)
        case .pciData: return Color(red: 0.05, green: 0.41, blue: 0.74)
        }
    }

    private var typeLabel: String {
        switch entity.type {
        case .phi: return "PHI"
        case .pii: return "PII"
        case .financial: return "FINANCIAL"
        case .credential: return "CREDENTIAL"
        case .pciData: return "PCI"
        }
    }

    private var enforcementInfo: (label: String, color: Color)? {
        guard let enforcement = entity.citedControl?.enforcement else { return nil }
        switch enforcement {
        case .block: return ("BLOCK", Color(red: 0.714, green: 0.110, blue: 0.110))
        case .warn: return ("WARN", Color(red: 0.86, green: 0.55, blue: 0.10))
        case .audit: return ("AUDIT", Color(red: 0.05, green: 0.41, blue: 0.74))
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(typeLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(iconColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(iconColor.opacity(0.12))
                        )
                    Text("\(Int(entity.confidence * 100))% confidence")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Text(entity.value)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            if let info = enforcementInfo {
                Text(info.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(info.color)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
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
        // Simulate a brief on-device scan so the UI can show its loading state.
        try await Task.sleep(nanoseconds: 600_000_000)

        let hipaaControl = CitedControl(
            framework: .hipaa,
            controlId: "HIPAA-164.502",
            title: "Uses and disclosures of protected health information",
            description: "Covered entities may not use or disclose PHI except as permitted or required by HIPAA.",
            enforcement: .block
        )
        let nistAccessControl = CitedControl(
            framework: .nistSP80053,
            controlId: "NIST-AC-3",
            title: "Access Enforcement",
            description: "Enforce approved authorizations for logical access to information and system resources.",
            enforcement: .warn
        )

        return AIClassificationResult(
            fileId: UUID(),
            sensitivity: .restricted,
            riskScore: 87,
            entities: [
                AIEntity(
                    id: UUID(),
                    type: .phi,
                    value: "Patient ID: 847293-A",
                    confidence: 0.97,
                    citedControl: hipaaControl
                ),
                AIEntity(
                    id: UUID(),
                    type: .phi,
                    value: "SSN: ***-**-4821",
                    confidence: 0.99,
                    citedControl: hipaaControl
                ),
                AIEntity(
                    id: UUID(),
                    type: .financial,
                    value: "Revenue: $124.7M",
                    confidence: 0.94,
                    citedControl: nistAccessControl
                )
            ],
            modelVersion: "CoreML-3.2",
            processingMs: 618,
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
    var currentBundle: PolicyBundle? {
        PolicyBundle(
            version: "1.0",
            signatureHex: String(repeating: "a", count: 64),
            rules: SensitivityLevel.allCases.map { level in
                PolicyRule(
                    id: UUID(),
                    name: "\(level.rawValue) Policy",
                    sensitivity: level,
                    allowExternalShare: level == .public_ || level == .internal_,
                    maxShareExpiryDays: level == .restricted ? nil : 30,
                    requireApprovalFromRole: level == .restricted ? "admin" : nil,
                    cloudAIPermitted: level == .public_
                )
            },
            fetchedAt: Date()
        )
    }

    func loadBundle(_ bundle: PolicyBundle) async throws {}

    func evaluate(operation: PolicyOperation, for file: SecureFile, actor: String) async -> PolicyDecision {
        // Default-deny external share for restricted files; allow others.
        let allowed: Bool
        switch (operation, file.sensitivity) {
        case (.openFile, _):
            allowed = true
        case (.shareExternally, .restricted), (.shareExternally, .confidential):
            allowed = false
        case (.shareExternally, _):
            allowed = true
        case (.uploadToCloud, .restricted):
            allowed = false
        default:
            allowed = true
        }

        let controls: [CitedControl] = file.sensitivity == .restricted
            ? [CitedControl(
                framework: .hipaa,
                controlId: "HIPAA-164.502",
                title: "Uses and disclosures of protected health information",
                description: "Covered entities may not use or disclose PHI except as permitted or required by HIPAA.",
                enforcement: .block
            )]
            : []

        return PolicyDecision(
            allowed: allowed,
            enforcement: allowed ? .audit : .block,
            citedControls: controls,
            requiredApprovalRole: allowed ? nil : "admin",
            auditRequired: true
        )
    }

    func rule(for sensitivity: SensitivityLevel) -> PolicyRule? {
        currentBundle?.rules.first { $0.sensitivity == sensitivity }
    }
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
