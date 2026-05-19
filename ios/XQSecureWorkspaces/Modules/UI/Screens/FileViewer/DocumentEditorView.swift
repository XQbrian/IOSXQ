import SwiftUI
import XQCore

struct DocumentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let file: SecureFile

    @State private var isEditing = false
    @State private var showAIAssist = false
    @State private var showTOC = false
    @State private var documentText: String
    @State private var aiSummary = ""
    @State private var isGeneratingSummary = false

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    init(file: SecureFile) {
        self.file = file
        _documentText = State(initialValue: DocumentEditorView.sampleContent(for: file))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                classificationBanner
                if isEditing { formattingToolbar }
                if showAIAssist { aiAssistPanel }
                documentBody
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            withAnimation { showTOC.toggle() }
                        } label: {
                            Image(systemName: "list.bullet.indent")
                                .font(.system(size: 16))
                                .foregroundColor(showTOC ? brandBlue : .primary)
                        }
                        Button {
                            withAnimation { showAIAssist.toggle() }
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                                .foregroundColor(showAIAssist ? brandBlue : .primary)
                        }
                        Button {
                            withAnimation { isEditing.toggle() }
                        } label: {
                            Text(isEditing ? "View" : "Edit")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(brandBlue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showTOC) {
                TOCSheet(file: file)
            }
        }
    }

    // MARK: - Classification Banner

    private var classificationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.system(size: 10))
            Text(file.sensitivity.editorBannerLabel)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(file.sensitivity.editorBannerColor)
    }

    // MARK: - Formatting Toolbar

    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                FormatButton(systemIcon: "bold")
                FormatButton(systemIcon: "italic")
                FormatButton(systemIcon: "underline")
                Divider().frame(height: 24)
                FormatButton(systemIcon: "list.bullet")
                FormatButton(systemIcon: "list.number")
                Divider().frame(height: 24)
                FormatButton(systemIcon: "text.alignleft")
                FormatButton(systemIcon: "text.aligncenter")
                FormatButton(systemIcon: "text.alignright")
                Divider().frame(height: 24)
                FormatButton(systemIcon: "link")
                FormatButton(systemIcon: "photo")
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 44)
        .background(Color(.secondarySystemBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - AI Assist Panel

    private var aiAssistPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "brain").font(.system(size: 13)).foregroundColor(brandBlue)
                Text("AI Document Assistant")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(brandBlue)
                Spacer()
                Button { withAnimation { showAIAssist = false } } label: {
                    Image(systemName: "xmark").font(.system(size: 12)).foregroundColor(.secondary)
                }
            }

            if aiSummary.isEmpty && !isGeneratingSummary {
                HStack(spacing: 8) {
                    AIAssistChip(label: "Summarize", brandBlue: brandBlue) { generateSummary() }
                    AIAssistChip(label: "Find Action Items", brandBlue: brandBlue) {}
                    AIAssistChip(label: "Improve Tone", brandBlue: brandBlue) {}
                }
            }

            if isGeneratingSummary {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Analyzing…").font(.system(size: 12)).foregroundColor(.secondary)
                }
            } else if !aiSummary.isEmpty {
                Text(aiSummary)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(brandBlue.opacity(0.06))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Document Body

    private var documentBody: some View {
        ScrollView {
            if isEditing {
                TextEditor(text: $documentText)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .frame(minHeight: 400)
            } else {
                Text(documentText)
                    .font(.system(size: 15))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func generateSummary() {
        isGeneratingSummary = true
        aiSummary = ""
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            let title = file.name.components(separatedBy: ".").first ?? "this document"
            aiSummary = "Summary for \(title): key findings include a 23% increase year-over-year, 3 action items identified — review variance, approve expansion, and finalize projections by month-end."
            isGeneratingSummary = false
        }
    }

    private static func sampleContent(for file: SecureFile) -> String {
        let title = file.name.components(separatedBy: ".").first ?? "Document"
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return """
        \(title)

        Last Modified: \(df.string(from: file.modifiedAt))
        Classification: \(file.sensitivity.rawValue.capitalized)
        Source: \(file.sourceProvider.rawValue)

        ────────────────────────────────────

        Executive Summary

        This document contains confidential information and is intended for authorized recipients only. The contents have been classified according to the organization's data governance policy and encrypted at rest with AES-256-GCM.

        Section 1 — Overview

        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

        Section 2 — Key Findings

        • Revenue increased 23% year-over-year
        • Headcount expansion approved for Q1
        • Budget variance under 5% across all departments
        • Compliance audit completed — no critical findings

        Section 3 — Recommendations

        Based on the analysis, the team recommends proceeding with the proposed initiative. All stakeholders have been consulted and the timeline has been approved by leadership.

        ────────────────────────────────────
        ENCRYPTED — AES-256-GCM · Secure Enclave key management
        """
    }
}

// MARK: - Supporting Views

private struct FormatButton: View {
    let systemIcon: String

    var body: some View {
        Button {} label: {
            Image(systemName: systemIcon)
                .font(.system(size: 15))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct AIAssistChip: View {
    let label: String
    let brandBlue: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(brandBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(brandBlue.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

private struct TOCSheet: View {
    @Environment(\.dismiss) private var dismiss
    let file: SecureFile

    var body: some View {
        NavigationStack {
            List {
                Section("Contents") {
                    TOCRow(indent: 0, title: "Executive Summary", page: 1)
                    TOCRow(indent: 0, title: "Section 1 — Overview", page: 2)
                    TOCRow(indent: 0, title: "Section 2 — Key Findings", page: 3)
                    TOCRow(indent: 1, title: "Revenue Analysis", page: 3)
                    TOCRow(indent: 1, title: "Headcount", page: 4)
                    TOCRow(indent: 0, title: "Section 3 — Recommendations", page: 5)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Table of Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct TOCRow: View {
    let indent: Int
    let title: String
    let page: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .padding(.leading, CGFloat(indent) * 16)
            Spacer()
            Text("\(page)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - SensitivityLevel editor helpers

private extension SensitivityLevel {
    var editorBannerLabel: String {
        switch self {
        case .public_:      return "PUBLIC"
        case .internal_:    return "INTERNAL — DO NOT DISTRIBUTE"
        case .confidential: return "CONFIDENTIAL — INTERNAL USE ONLY"
        case .restricted:   return "RESTRICTED — PHI DETECTED"
        }
    }
    var editorBannerColor: Color {
        switch self {
        case .public_:      return Color(red: 0.106, green: 0.369, blue: 0.125)
        case .internal_:    return Color(red: 0.051, green: 0.278, blue: 0.631)
        case .confidential: return Color(red: 0.427, green: 0.298, blue: 0.000)
        case .restricted:   return Color(red: 0.482, green: 0.000, blue: 0.200)
        }
    }
}

#Preview {
    DocumentEditorView(file: SecureFile(
        id: UUID(), name: "Q4-Financial-Report.xlsx",
        mimeType: "application/vnd.ms-excel", sizeBytes: 245_760,
        sensitivity: .confidential, encryptedKeyId: "key-q4",
        sourceProvider: .sharePoint,
        modifiedAt: Date().addingTimeInterval(-86400 * 3),
        riskScore: nil
    ))
}
