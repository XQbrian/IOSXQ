import SwiftUI
import XQCore

struct SemanticSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var query = ""
    @State private var results: [SemanticResult] = []
    @State private var isSearching = false
    @State private var selectedFile: SecureFile?
    @FocusState private var queryFocused: Bool

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    private let suggestedQueries = [
        "contracts expiring this quarter",
        "files with PHI data",
        "shared externally last 30 days",
        "patient records 2025",
        "credentials or passwords",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if query.isEmpty {
                    suggestionsContent
                } else if isSearching {
                    searchingState
                } else {
                    resultsContent
                }
            }
            .navigationTitle("AI Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedFile) { file in
                NavigationStack {
                    FileViewerView(file: file)
                }
                .environmentObject(coordinator)
            }
        }
        .onAppear { queryFocused = true }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(brandBlue)
            TextField("Search files with natural language…", text: $query)
                .font(.system(size: 16))
                .focused($queryFocused)
                .submitLabel(.search)
                .onSubmit { performSearch() }
            if !query.isEmpty {
                Button { query = ""; results = [] } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Suggestions

    private var suggestionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                insightCard
                suggestionsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .font(.system(size: 14))
                    .foregroundColor(brandBlue)
                Text("AI File Intelligence")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(brandBlue)
            }
            Text("Search using natural language. Ask questions about file content, sensitivity, or sharing status — AI understands context, not just keywords.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(brandBlue.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            VStack(spacing: 8) {
                ForEach(suggestedQueries, id: \.self) { suggestion in
                    Button {
                        query = suggestion
                        performSearch()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(suggestion)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 12))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Searching

    private var searchingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.2)
            Text("Searching with AI…")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Results

    private var resultsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("\(results.count) result\(results.count == 1 ? "" : "s") for")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("\"\(query)\"")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 2)

                VStack(spacing: 0) {
                    ForEach(results) { result in
                        SemanticResultRow(result: result) {
                            selectedFile = result.file
                        }
                        if result.id != results.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    // MARK: - Search Logic

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            results = SemanticResult.mock(for: query)
            isSearching = false
        }
    }
}

// MARK: - Result Row

private struct SemanticResultRow: View {
    let result: SemanticResult
    let onTap: () -> Void

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(brandBlue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Text(result.fileExt.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(brandBlue)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.file.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(result.excerpt)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(String(format: "%.0f%%", result.relevance * 100) + " match")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(brandBlue)
                        Text("·").foregroundColor(.secondary)
                        Text(result.file.sensitivity.rawValue.capitalized)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model

struct SemanticResult: Identifiable {
    let id = UUID()
    let file: SecureFile
    let excerpt: String
    let relevance: Double

    var fileExt: String { file.name.components(separatedBy: ".").last ?? "file" }

    static func mock(for query: String) -> [SemanticResult] {
        let files: [SecureFile] = [
            SecureFile(id: UUID(), name: "Q4-Financial-Report.xlsx",
                       mimeType: "application/vnd.ms-excel", sizeBytes: 245_760,
                       sensitivity: .confidential, encryptedKeyId: "key-q4",
                       sourceProvider: .sharePoint, modifiedAt: Date().addingTimeInterval(-86400 * 3),
                       riskScore: nil),
            SecureFile(id: UUID(), name: "Patient-Records-2025.pdf",
                       mimeType: "application/pdf", sizeBytes: 1_048_576,
                       sensitivity: .restricted, encryptedKeyId: "key-pr",
                       sourceProvider: .sharePoint, modifiedAt: Date().addingTimeInterval(-86400 * 7),
                       riskScore: nil),
            SecureFile(id: UUID(), name: "Vendor-Contract-Draft.docx",
                       mimeType: "application/msword", sizeBytes: 87_040,
                       sensitivity: .internal_, encryptedKeyId: "key-vc",
                       sourceProvider: .sharePoint, modifiedAt: Date().addingTimeInterval(-86400 * 1),
                       riskScore: nil),
            SecureFile(id: UUID(), name: "Security-Audit-Report.pdf",
                       mimeType: "application/pdf", sizeBytes: 512_000,
                       sensitivity: .restricted, encryptedKeyId: "key-sa",
                       sourceProvider: .sharePoint, modifiedAt: Date().addingTimeInterval(-86400 * 14),
                       riskScore: nil),
        ]
        let excerpts = [
            "…contains \(query) data classified as confidential…",
            "…relevant to query: '\(query)' with high confidence…",
            "…file references \(query) in section 3.2…",
            "…metadata indicates \(query) relationship…",
        ]
        return files.enumerated().map { idx, file in
            SemanticResult(
                file: file,
                excerpt: excerpts[idx % excerpts.count],
                relevance: 0.98 - Double(idx) * 0.09
            )
        }
    }
}
