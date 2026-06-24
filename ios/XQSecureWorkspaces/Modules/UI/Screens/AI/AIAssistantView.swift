import SwiftUI

// MARK: - DLP Models

enum ClearanceLevel: Int, CaseIterable, Comparable {
    case l1 = 1, l2 = 2, l3 = 3, l4 = 4

    static func < (lhs: ClearanceLevel, rhs: ClearanceLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .l1: return "L1 Basic"
        case .l2: return "L2 Standard"
        case .l3: return "L3 Elevated"
        case .l4: return "L4 Executive"
        }
    }

    var shortLabel: String { "L\(rawValue)" }

    var color: Color {
        switch self {
        case .l1: return .secondary
        case .l2: return .blue
        case .l3: return .orange
        case .l4: return .red
        }
    }
}

enum DLPScanState: Equatable {
    case idle, scanning, cleared, softWarning, hardBlocked
}

enum DLPResponseState: Equatable {
    case cleared, partialRedaction, fullRestriction
}

enum ContentSegment {
    case text(String)
    case redacted(requiredLevel: ClearanceLevel)
}

// MARK: - Main View

struct AIAssistantView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var messages: [AIMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var dlpScanState: DLPScanState = .idle
    @State private var pendingText: String?
    @FocusState private var inputFocused: Bool

    private let userClearance: ClearanceLevel = .l2
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let aiPurple = Color(red: 0.686, green: 0.322, blue: 0.871)

    var body: some View {
        VStack(spacing: 0) {
            dlpStatusBar
            if messages.isEmpty {
                welcomeState
            } else {
                messageList
            }
            inputBar
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                clearanceBadge
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !messages.isEmpty {
                    Button {
                        withAnimation { messages = []; dlpScanState = .idle }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("New conversation")
                }
            }
        }
    }

    // MARK: - DLP Status Bar

    private var dlpStatusBar: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(dlpStatusColor).frame(width: 6, height: 6)
                if dlpScanState == .scanning {
                    Circle().fill(dlpStatusColor.opacity(0.35)).frame(width: 11, height: 11)
                }
            }
            Text(dlpStatusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(dlpStatusColor)
            Spacer()
            if dlpScanState == .scanning {
                ProgressView().scaleEffect(0.6).tint(dlpStatusColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(dlpStatusColor.opacity(0.07))
        .animation(.easeInOut(duration: 0.3), value: dlpScanState)
    }

    private var dlpStatusColor: Color {
        switch dlpScanState {
        case .idle, .cleared: return .green
        case .scanning:        return .blue
        case .softWarning:     return .orange
        case .hardBlocked:     return .red
        }
    }

    private var dlpStatusText: String {
        switch dlpScanState {
        case .idle, .cleared: return "DLP Active — all messages scanned"
        case .scanning:        return "Checking message for sensitive data…"
        case .softWarning:     return "DLP Warning — sensitive data detected"
        case .hardBlocked:     return "DLP Alert — message blocked"
        }
    }

    // MARK: - Clearance Badge

    private var clearanceBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(userClearance.color).frame(width: 5, height: 5)
            Text("\(userClearance.shortLabel) Clearance")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(userClearance.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(userClearance.color.opacity(0.12))
                .overlay(Capsule().stroke(userClearance.color.opacity(0.3), lineWidth: 0.5))
        )
    }

    // MARK: - Welcome State

    private var welcomeState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(aiPurple.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: AppIcon.ai)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(aiPurple)
                }
                Text("What can I help with?")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("DLP active · \(userClearance.label)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 32)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                SuggestionCard(
                    icon: "doc.text.magnifyingglass", color: .blue,
                    title: "Find sensitive files",
                    subtitle: "Scan for PHI, PII, or restricted content"
                ) { send("Which files contain PHI or restricted data?") }

                SuggestionCard(
                    icon: "link.circle.fill", color: .orange,
                    title: "Check sharing",
                    subtitle: "Review expiring links and permissions"
                ) { send("Are any of my shared files expiring soon?") }

                SuggestionCard(
                    icon: "exclamationmark.shield.fill", color: .red,
                    title: "Security alerts",
                    subtitle: "Phishing, policy blocks, anomalies"
                ) { send("Show me recent phishing or security alerts") }

                SuggestionCard(
                    icon: "tag.fill", color: aiPurple,
                    title: "Classify uploads",
                    subtitle: "Auto-tag and organize recent files"
                ) { send("Classify and organize my recent uploads") }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        messageRow(for: msg).id(msg.id)
                    }
                    if isTyping {
                        TypingIndicator(aiPurple: aiPurple).id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: isTyping) { _, typing in
                if typing { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    @ViewBuilder
    private func messageRow(for msg: AIMessage) -> some View {
        VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 6) {
            if msg.role == .user {
                userMessageRow(msg)
            } else {
                assistantMessageRow(msg)
            }
        }
        .frame(maxWidth: .infinity, alignment: msg.role == .user ? .trailing : .leading)
    }

    @ViewBuilder
    private func userMessageRow(_ msg: AIMessage) -> some View {
        MessageBubble(message: msg, aiPurple: aiPurple)
        switch msg.dlpOutbound {
        case .idle:
            EmptyView()
        case .scanning:
            DLPStatusChip(text: "Scanning for sensitive data…", color: .blue)
        case .cleared:
            DLPStatusChip(text: "✓ DLP Cleared — sent", color: .green)
        case .softWarning:
            VStack(alignment: .trailing, spacing: 6) {
                DLPStatusChip(text: "⚠ Sensitive data detected", color: .orange)
                DLPSoftWarningView(
                    onEdit: {
                        if let t = pendingText { inputText = t; pendingText = nil }
                        removeMessage(id: msg.id)
                        dlpScanState = .idle
                    },
                    onSendAnyway: { proceedWithSend(replacing: msg.id) }
                )
            }
        case .hardBlocked:
            VStack(alignment: .trailing, spacing: 6) {
                DLPStatusChip(text: "🚫 Blocked — not sent", color: .red)
                DLPHardBlockView(
                    onEdit: {
                        if let t = pendingText { inputText = t; pendingText = nil }
                        removeMessage(id: msg.id)
                        dlpScanState = .idle
                    },
                    onRequestException: {
                        removeMessage(id: msg.id)
                        dlpScanState = .idle
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func assistantMessageRow(_ msg: AIMessage) -> some View {
        switch msg.dlpResponse {
        case .cleared:
            MessageBubble(message: msg, aiPurple: aiPurple)
            DLPStatusChip(text: "✓ \(userClearance.shortLabel) filter applied", color: .green)
        case .partialRedaction:
            SegmentedMessageBubble(segments: msg.segments ?? [], aiPurple: aiPurple)
            DLPStatusChip(text: "▓ \(userClearance.shortLabel) filter — some sections restricted", color: .secondary)
        case .fullRestriction:
            DLPFullRestrictionView()
            DLPStatusChip(text: "🔒 Response fully restricted", color: .red)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    if inputText.isEmpty {
                        Text("Ask anything…")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                    TextField("", text: $inputText, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))

                let canSend = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && dlpScanState != .scanning

                Button {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    send(text)
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? brandBlue : Color(.systemGray4))
                            .frame(width: 34, height: 34)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, 4)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - DLP Logic

    private func send(_ text: String) {
        inputText = ""
        inputFocused = false
        pendingText = text
        dlpScanState = .scanning

        var userMsg = AIMessage(role: .user, content: text)
        userMsg.dlpOutbound = .scanning
        withAnimation { messages.append(userMsg) }

        let msgId = userMsg.id
        Task {
            try? await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000...900_000_000))
            let score = dlpRiskScore(for: text)
            let state: DLPScanState = score >= 71 ? .hardBlocked : score >= 31 ? .softWarning : .cleared

            await MainActor.run {
                dlpScanState = state
                if let idx = messages.firstIndex(where: { $0.id == msgId }) {
                    messages[idx].dlpOutbound = state
                }
                if state == .cleared { fetchAIResponse(for: text) }
            }
        }
    }

    private func proceedWithSend(replacing msgId: UUID) {
        guard let text = pendingText else { return }
        pendingText = nil
        if let idx = messages.firstIndex(where: { $0.id == msgId }) {
            messages[idx].dlpOutbound = .cleared
        }
        dlpScanState = .cleared
        fetchAIResponse(for: text)
    }

    private func fetchAIResponse(for query: String) {
        isTyping = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            let (content, responseState, segments) = generateReply(for: query)

            await MainActor.run {
                isTyping = false
                var aiMsg = AIMessage(role: .assistant, content: content)
                aiMsg.dlpResponse = responseState
                aiMsg.segments = segments
                withAnimation { messages.append(aiMsg) }
                dlpScanState = responseState == .fullRestriction ? .hardBlocked : .cleared
            }
        }
    }

    private func removeMessage(id: UUID) {
        withAnimation { messages.removeAll { $0.id == id } }
    }

    private func dlpRiskScore(for text: String) -> Int {
        let lower = text.lowercased()
        let ssnRegex = try? NSRegularExpression(pattern: #"\d{3}-\d{2}-\d{4}"#)
        let hasSsn = ssnRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil

        if hasSsn || lower.contains("m&a") || lower.contains("term sheet") ||
           lower.contains("cap table") || lower.contains("merger") || lower.contains("acquisition target") {
            return Int.random(in: 72...95)
        }
        if lower.contains("salary") || lower.contains("medical record") ||
           lower.contains("patient") || lower.contains("employee id") ||
           lower.contains("confidential") || lower.contains("pii") {
            return Int.random(in: 32...65)
        }
        return Int.random(in: 0...25)
    }

    private func generateReply(for query: String) -> (String, DLPResponseState, [ContentSegment]?) {
        let lower = query.lowercased()

        if lower.contains("q3") || lower.contains("quarterly") ||
           lower.contains("revenue") || lower.contains("financial") {
            let base = "Q3 financial summary: Revenue came in at $47.2M, up 14% YoY. Operating margin improved to 22%."
            if userClearance >= .l3 {
                return (base + " Board forecast targets 28% growth for Q4.", .cleared, nil)
            }
            return (base, .partialRedaction, [.text(base), .redacted(requiredLevel: .l3)])
        }

        if lower.contains("cap table") || lower.contains("term sheet") || lower.contains("series c") {
            return ("", .fullRestriction, nil)
        }

        if lower.contains("restrict") || lower.contains("phi") {
            return ("I found 3 files classified as Restricted containing potential PHI. These cannot be shared externally and require admin approval.\n\n• Patient-Records-2025.pdf\n• Medical-Claims-Q4.xlsx\n• Insurance-Summary.docx\n\nAll analysis ran on-device.", .cleared, nil)
        }

        if lower.contains("phish") || lower.contains("email") {
            return ("1 high-risk phishing alert detected — spoofing a Microsoft domain with a suspicious attachment. Flagged in your Alerts tab.", .cleared, nil)
        }

        if lower.contains("share") || lower.contains("expir") || lower.contains("link") {
            return ("2 shared links expire within 24 hours:\n\n• Patient-Records-2025.pdf — tomorrow\n• Q4-Report.xlsx — 18 hours\n\nShall I renew them or generate new encrypted links?", .cleared, nil)
        }

        if lower.contains("classif") || lower.contains("organiz") {
            return ("On-device scan of 47 files complete:\n\n• 8 need reclassification (>85% confidence)\n• 3 duplicates detected\n• 14 files inactive 90+ days — archive candidates\n\nNo data left your device.", .cleared, nil)
        }

        return ("I can help analyze your secure files, review compliance status, check sharing permissions, or identify risks — all on-device. What would you like to explore?", .cleared, nil)
    }
}

// MARK: - Message Model

struct AIMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    var dlpOutbound: DLPScanState = .cleared
    var dlpResponse: DLPResponseState = .cleared
    var segments: [ContentSegment]?

    enum Role { case user, assistant }

    static let suggestions = [
        "Which files contain PHI or restricted data?",
        "Are any of my shared links about to expire?",
        "Classify and organize my recent uploads",
        "Show me potential phishing risks in my inbox",
    ]
}

// MARK: - Sub-views

private struct MessageBubble: View {
    let message: AIMessage
    let aiPurple: Color
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser {
                ZStack {
                    Circle().fill(aiPurple.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: AppIcon.ai)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(aiPurple)
                }
            }

            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(isUser ? .white : .primary)
                .strikethrough(message.dlpOutbound == .hardBlocked, color: .white.opacity(0.5))
                .opacity(message.dlpOutbound == .hardBlocked ? 0.45 : 1)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isUser
                              ? Color(red: 0.239, green: 0.353, blue: 0.996)
                              : Color(.secondarySystemBackground))
                )
                .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)

            if isUser { Spacer().frame(width: 4) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

private struct SegmentedMessageBubble: View {
    let segments: [ContentSegment]
    let aiPurple: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(aiPurple.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: AppIcon.ai)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(aiPurple)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(segments.indices, id: \.self) { i in
                    switch segments[i] {
                    case .text(let t):
                        Text(t).font(.system(size: 15)).foregroundColor(.primary)
                    case .redacted(let level):
                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill").font(.system(size: 9))
                            Text("██ — \(level.label) required")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray)))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
            .frame(maxWidth: 280, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DLPStatusChip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
    }
}

private struct DLPSoftWarningView: View {
    let onEdit: () -> Void
    let onSendAnyway: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sensitive data detected", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
            Text("Your message may contain personal identifiers. You can edit it or proceed — your choice is recorded for compliance.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                Button("Edit message", action: onEdit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
                    )
                Button("Send anyway →", action: onSendAnyway)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.25), lineWidth: 0.5))
        )
        .frame(maxWidth: 300, alignment: .trailing)
    }
}

private struct DLPHardBlockView: View {
    let onEdit: () -> Void
    let onRequestException: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("This message couldn't be sent", systemImage: "xmark.shield.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.red)
            Text("Your message contains information that can't leave this secure environment. Edit it or contact IT to request a policy exception.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                Button("Edit message", action: onEdit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
                    )
                Button("Request exception", action: onRequestException)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
        )
        .frame(maxWidth: 300, alignment: .trailing)
    }
}

private struct DLPFullRestrictionView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text("Response restricted")
                    .font(.system(size: 13, weight: .semibold))
                Text("The answer to your question requires a higher access level than your current session allows. Your IT team has been notified.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    Button("Request upgrade") {}
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.blue)
                    Text("·").foregroundColor(.secondary)
                    Button("Ask differently") {}
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator).opacity(0.5), lineWidth: 0.5))
        )
        .frame(maxWidth: 300, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 36)
    }
}

private struct SuggestionCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
                    .padding(.bottom, 10)
                Spacer(minLength: 0)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.bottom, 2)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }
}

private struct TypingIndicator: View {
    let aiPurple: Color
    @State private var dotScale: [CGFloat] = [1, 1, 1]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(aiPurple.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: AppIcon.ai)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(aiPurple)
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(dotScale[i])
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animateDots() }
    }

    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.15)
            ) {
                dotScale[i] = 0.4
            }
        }
    }
}
