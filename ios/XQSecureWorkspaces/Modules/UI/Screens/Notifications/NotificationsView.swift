import SwiftUI

// MARK: - Security Status

private struct NowSecurityStatus {
    var dataRisk: DataRisk = .medium
    var compliancePercent: Int = 97
    var sensitiveFileCount: Int = 4283
    var openAlerts: Int = 3

    enum DataRisk {
        case low, medium, high, critical
        var label: String {
            switch self {
            case .low:      return "Low Risk"
            case .medium:   return "Medium Risk"
            case .high:     return "High Risk"
            case .critical: return "Critical"
            }
        }
        var color: Color {
            switch self {
            case .low:      return .green
            case .medium:   return .orange
            case .high:     return Color(red: 1, green: 0.3, blue: 0)
            case .critical: return .red
            }
        }
    }
}

// MARK: - AI Insight

private enum InsightSeverity { case warning, critical, success, info }

private struct NowAIInsight: Identifiable {
    let id = UUID()
    let severity: InsightSeverity
    let text: String
    let actionLabel: String
    let query: String

    var icon: String {
        switch severity {
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        case .success:  return "checkmark.circle.fill"
        case .info:     return "info.circle.fill"
        }
    }

    var color: Color {
        switch severity {
        case .warning:  return .orange
        case .critical: return .red
        case .success:  return .green
        case .info:     return .blue
        }
    }

    static let defaults: [NowAIInsight] = [
        NowAIInsight(severity: .warning,  text: "12 sensitive files shared externally this week",  actionLabel: "Investigate →", query: "Show me sensitive files shared externally this week"),
        NowAIInsight(severity: .warning,  text: "3 policy violations require your review",              actionLabel: "Review →",      query: "Show me the 3 policy violations that need review"),
        NowAIInsight(severity: .success,  text: "No critical compliance issues detected",               actionLabel: "Details →",     query: "Give me a full compliance status report"),
        NowAIInsight(severity: .warning,  text: "5 users have excessive data permissions",              actionLabel: "Review →",      query: "Which users have excessive data access permissions?"),
        NowAIInsight(severity: .success,  text: "Data discovery scan complete — 4,283 files indexed",  actionLabel: "View →",        query: "What did the data discovery scan find?"),
    ]
}

// MARK: - Now Message

private struct NowActionButton: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
}

private struct NowMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    var dlpState: DLPScanState = .cleared
    var dlpResponse: DLPResponseState = .cleared
    var segments: [ContentSegment]?
    var actionButtons: [NowActionButton] = []
    var isBlocked = false

    enum Role { case user, assistant }
}

// MARK: - Now Tab

struct NowTabView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var messages: [NowMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var dlpScanState: DLPScanState = .idle
    @State private var pendingText: String?
    @State private var security = NowSecurityStatus()
    @State private var showingActivity = false
    @State private var notifications = AppNotification.samples
    @FocusState private var inputFocused: Bool

    private let userClearance: ClearanceLevel = .l2
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let aiPurple = Color(red: 0.686, green: 0.322, blue: 0.871)
    private var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                securityStatusBar
                Divider()
                if messages.isEmpty {
                    emptyState
                } else {
                    conversationFeed
                }
                inputBar
            }
            .navigationTitle("Now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navBar }
        }
        .sheet(isPresented: $showingActivity) {
            ActivitySheet(notifications: $notifications)
        }
    }

    // MARK: - Nav Bar

    @ToolbarContentBuilder
    private var navBar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            clearanceBadge
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 14) {
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
                Button { showingActivity = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        if unreadCount > 0 {
                            Circle().fill(Color.red)
                                .frame(width: 7, height: 7)
                                .offset(x: 3, y: -2)
                        }
                    }
                }
                .accessibilityLabel("Activity — \(unreadCount) unread")
                Button { coordinator.presentProfile() } label: {
                    ZStack {
                        Circle().fill(brandBlue).frame(width: 28, height: 28)
                        Text("BW").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    }
                }
                .accessibilityLabel("Open Profile")
            }
        }
    }

    // MARK: - Security Status Bar

    private var securityStatusBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                SecurityPill(label: security.dataRisk.label, color: security.dataRisk.color, icon: "gauge.medium")
                SecurityPill(
                    label: "\(security.compliancePercent)% Compliant",
                    color: security.compliancePercent >= 95 ? .green : .orange,
                    icon: "checkmark.shield.fill"
                )
                SecurityPill(
                    label: "\(security.sensitiveFileCount.formatted()) files",
                    color: .secondary,
                    icon: "doc.text.fill"
                )
                SecurityPill(
                    label: "\(security.openAlerts) alert\(security.openAlerts == 1 ? "" : "s")",
                    color: security.openAlerts > 0 ? .red : .green,
                    icon: security.openAlerts > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ask about your data.")
                        .font(.system(size: 26, weight: .bold))
                    Text("Governance, compliance, and security through conversation.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Label("AI Insights", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        ForEach(NowAIInsight.defaults) { insight in
                            NowInsightCard(insight: insight) { send(insight.query) }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggested Actions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestionActions, id: \.label) { action in
                                NowSuggestionChip(label: action.label, icon: action.icon, brandBlue: brandBlue) {
                                    send(action.query)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 40)
            }
        }
    }

    private var suggestionActions: [(label: String, icon: String, query: String)] {
        [
            ("Investigate Risks",       "binoculars.fill",         "What are the top data risks I should investigate right now?"),
            ("Review External Sharing", "arrow.up.forward.circle", "Show me sensitive files shared externally this week"),
            ("Check Compliance",        "checkmark.shield",        "What compliance risks need my attention today?"),
            ("CMMC Readiness",          "doc.badge.gearshape",     "Generate a CMMC Level 2 readiness report"),
            ("Exec Summary",            "doc.richtext.fill",       "Generate an executive data governance summary for today"),
        ]
    }

    // MARK: - Conversation Feed

    private var conversationFeed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { msg in
                        messageRow(for: msg).id(msg.id)
                    }
                    if isTyping { typingRow.id("typing") }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
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
    private func messageRow(for msg: NowMessage) -> some View {
        if msg.role == .user {
            userRow(msg).frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            assistantRow(msg).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func userRow(_ msg: NowMessage) -> some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(msg.content)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18).fill(brandBlue))
                .overlay(
                    msg.isBlocked
                        ? RoundedRectangle(cornerRadius: 18).stroke(Color.red.opacity(0.4), lineWidth: 1.5)
                        : nil
                )
                .opacity(msg.isBlocked ? 0.45 : 1)
                .frame(maxWidth: 280, alignment: .trailing)

            switch msg.dlpState {
            case .scanning:
                HStack(spacing: 5) {
                    ProgressView().scaleEffect(0.65).tint(.blue)
                    Text("Scanning…").font(.system(size: 10)).foregroundColor(.blue)
                }
            case .cleared:
                Text("✓ Cleared").font(.system(size: 10)).foregroundColor(.green)
            case .softWarning:
                softWarningCard(for: msg)
            case .hardBlocked:
                hardBlockCard(for: msg)
            case .idle:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func assistantRow(_ msg: NowMessage) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            switch msg.dlpResponse {
            case .cleared:
                HStack(alignment: .bottom, spacing: 8) {
                    aiAvatar
                    VStack(alignment: .leading, spacing: 8) {
                        Text(msg.content)
                            .font(.system(size: 15))
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
                            .frame(maxWidth: 280, alignment: .leading)

                        if !msg.actionButtons.isEmpty {
                            actionButtonRow(msg.actionButtons)
                        }
                    }
                }
                Text("✓ \(userClearance.shortLabel) filter applied")
                    .font(.system(size: 10)).foregroundColor(.green)
                    .padding(.leading, 36)

            case .partialRedaction:
                HStack(alignment: .bottom, spacing: 8) {
                    aiAvatar
                    segmentedContent(msg.segments ?? [])
                }
                Text("▓ Sections restricted (\(userClearance.shortLabel))")
                    .font(.system(size: 10)).foregroundColor(.secondary)
                    .padding(.leading, 36)

            case .fullRestriction:
                HStack(alignment: .top, spacing: 10) {
                    aiAvatar
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Response restricted", systemImage: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("This content requires a higher clearance level. Your IT team has been notified.")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                        Button("Request access upgrade") {}
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(brandBlue)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                }
                Text("🔒 Fully restricted").font(.system(size: 10)).foregroundColor(.red)
                    .padding(.leading, 36)
            }
        }
    }

    private func segmentedContent(_ segments: [ContentSegment]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(segments.indices, id: \.self) { i in
                switch segments[i] {
                case .text(let t):
                    Text(t).font(.system(size: 15))
                case .redacted(let level):
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 9))
                        Text("██ — \(level.label) required").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray)))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        .frame(maxWidth: 280, alignment: .leading)
    }

    private func actionButtonRow(_ buttons: [NowActionButton]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(buttons) { btn in
                    Button {} label: {
                        HStack(spacing: 5) {
                            Image(systemName: btn.icon).font(.system(size: 11))
                            Text(btn.label).font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(brandBlue)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(brandBlue.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(brandBlue.opacity(0.25), lineWidth: 0.75))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func softWarningCard(for msg: NowMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sensitive data detected", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.orange)
            Text("This message may contain personal identifiers. You can edit it or proceed — your choice is logged.")
                .font(.system(size: 12)).foregroundColor(.secondary)
            HStack(spacing: 8) {
                Button("Edit") {
                    if let t = pendingText { inputText = t; pendingText = nil }
                    removeMessage(id: msg.id); dlpScanState = .idle
                }
                .buttonStyle(NowOutlinePillStyle())
                Button("Send anyway →") { proceedWithSend(replacing: msg.id) }
                    .buttonStyle(NowFilledPillStyle(color: .orange))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.25), lineWidth: 0.5))
        )
        .frame(maxWidth: 300)
    }

    @ViewBuilder
    private func hardBlockCard(for msg: NowMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Message blocked", systemImage: "xmark.shield.fill")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.red)
            Text("This message contains information that can't leave this secure environment.")
                .font(.system(size: 12)).foregroundColor(.secondary)
            HStack(spacing: 8) {
                Button("Edit") {
                    if let t = pendingText { inputText = t; pendingText = nil }
                    removeMessage(id: msg.id); dlpScanState = .idle
                }
                .buttonStyle(NowOutlinePillStyle())
                Button("Request exception") { removeMessage(id: msg.id); dlpScanState = .idle }
                    .buttonStyle(NowFilledPillStyle(color: .red))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
        )
        .frame(maxWidth: 300)
    }

    private var aiAvatar: some View {
        ZStack {
            Circle().fill(aiPurple.opacity(0.15)).frame(width: 28, height: 28)
            Image(systemName: AppIcon.ai)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(aiPurple)
        }
    }

    private var typingRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            aiAvatar
            NowTypingDotsView()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                Circle()
                    .fill(dlpStatusColor)
                    .frame(width: 5, height: 5)
                    .padding(.bottom, 13)
                    .animation(.easeInOut(duration: 0.3), value: dlpScanState)

                ZStack(alignment: .leading) {
                    if inputText.isEmpty {
                        Text("Ask about your data…")
                            .font(.system(size: 15))
                            .foregroundColor(Color(.placeholderText))
                            .padding(.leading, 4)
                    }
                    TextField("", text: $inputText, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(1...5)
                        .focused($inputFocused)
                        .padding(.horizontal, 4)
                        .onSubmit {
                            let t = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty { send(t) }
                        }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))

                let canSend = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && dlpScanState != .scanning

                Button {
                    let t = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    send(t)
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
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 6)

            if dlpScanState == .scanning || dlpScanState == .softWarning || dlpScanState == .hardBlocked {
                Text(dlpStatusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(dlpStatusColor)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
        .background(Color(.systemBackground))
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
        case .idle, .cleared: return ""
        case .scanning:        return "Scanning for sensitive data…"
        case .softWarning:     return "Sensitive data detected"
        case .hardBlocked:     return "Message blocked by DLP policy"
        }
    }

    private var clearanceBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(userClearance.color).frame(width: 5, height: 5)
            Text("\(userClearance.shortLabel) Clearance")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(userClearance.color)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            Capsule()
                .fill(userClearance.color.opacity(0.12))
                .overlay(Capsule().stroke(userClearance.color.opacity(0.3), lineWidth: 0.5))
        )
    }

    // MARK: - DLP Logic

    private func send(_ text: String) {
        inputText = ""
        inputFocused = false
        pendingText = text
        dlpScanState = .scanning

        var msg = NowMessage(role: .user, content: text)
        msg.dlpState = .scanning
        withAnimation { messages.append(msg) }

        let msgId = msg.id
        Task {
            try? await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000...900_000_000))
            let score = dlpRiskScore(for: text)
            let state: DLPScanState = score >= 71 ? .hardBlocked : score >= 31 ? .softWarning : .cleared

            await MainActor.run {
                dlpScanState = state
                if let idx = messages.firstIndex(where: { $0.id == msgId }) {
                    messages[idx].dlpState = state
                    messages[idx].isBlocked = state == .hardBlocked
                }
                if state == .cleared { fetchResponse(for: text) }
            }
        }
    }

    private func proceedWithSend(replacing msgId: UUID) {
        guard let text = pendingText else { return }
        pendingText = nil
        if let idx = messages.firstIndex(where: { $0.id == msgId }) {
            messages[idx].dlpState = .cleared
            messages[idx].isBlocked = false
        }
        dlpScanState = .cleared
        fetchResponse(for: text)
    }

    private func fetchResponse(for query: String) {
        isTyping = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            let (content, responseState, segments, buttons) = generateResponse(for: query)
            await MainActor.run {
                isTyping = false
                var msg = NowMessage(role: .assistant, content: content)
                msg.dlpResponse = responseState
                msg.segments = segments
                msg.actionButtons = buttons
                withAnimation { messages.append(msg) }
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
           lower.contains("cap table") || lower.contains("acquisition target") {
            return Int.random(in: 72...95)
        }
        if lower.contains("salary") || lower.contains("medical record") ||
           lower.contains("patient id") || lower.contains("employee ssn") {
            return Int.random(in: 32...65)
        }
        return Int.random(in: 0...25)
    }

    private func generateResponse(for query: String) -> (String, DLPResponseState, [ContentSegment]?, [NowActionButton]) {
        let lower = query.lowercased()

        if lower.contains("external") || lower.contains("sharing") || lower.contains("shared") {
            return (
                "Found 14 files containing CUI.\n3 are shared outside approved domains.\n2 violate policy XQ-DLP-07.",
                .cleared, nil,
                [
                    NowActionButton(label: "Review Files",    icon: "doc.text.magnifyingglass"),
                    NowActionButton(label: "Revoke Access",   icon: "xmark.circle"),
                    NowActionButton(label: "Generate Report", icon: "doc.richtext"),
                ]
            )
        }

        if lower.contains("risk") || lower.contains("investigate") {
            return (
                "Top risks right now:\n\n• 12 sensitive files shared externally\n• 3 policy violations pending\n• 5 users with excessive permissions\n• 1 unencrypted file in public storage",
                .cleared, nil,
                [
                    NowActionButton(label: "Fix Violations",    icon: "exclamationmark.shield"),
                    NowActionButton(label: "Audit Permissions", icon: "person.badge.key"),
                    NowActionButton(label: "Encrypt File",      icon: "lock.fill"),
                ]
            )
        }

        if lower.contains("compliance") || lower.contains("cmmc") {
            return (
                "Compliance: 97% · CMMC Level 2\n\n✓ Access controls — Compliant\n✓ Data classification — Compliant\n⚠ Audit logging — 2 gaps\n⚠ External sharing policy — 3 violations",
                .cleared, nil,
                [
                    NowActionButton(label: "Fix Audit Gaps", icon: "wrench.adjustable"),
                    NowActionButton(label: "CMMC Report",    icon: "doc.richtext"),
                ]
            )
        }

        if lower.contains("policy violation") {
            return (
                "3 open policy violations:\n\n1. Q4-Board-Deck.pdf — shared with unverified domain\n2. HR-Salaries-2025.xlsx — external link active 47 days\n3. Patient-Data-Extract.csv — no encryption at rest",
                .cleared, nil,
                [
                    NowActionButton(label: "Resolve All",  icon: "checkmark.circle"),
                    NowActionButton(label: "Notify Owner", icon: "envelope"),
                ]
            )
        }

        if lower.contains("permission") || lower.contains("access") {
            let base = "5 users have permissions beyond their role scope."
            return (
                base, .partialRedaction,
                [.text(base), .redacted(requiredLevel: .l3)],
                [NowActionButton(label: "Review Permissions", icon: "person.badge.key")]
            )
        }

        if lower.contains("phi") || lower.contains("restricted") {
            return ("", .fullRestriction, nil, [])
        }

        if lower.contains("executive") || lower.contains("summary") {
            return (
                "Executive Summary — Today\n\n🔒 4,283 sensitive files protected\n⚠ 3 open alerts require attention\n✓ 97% CMMC L2 compliance\n✓ No critical incidents in last 24h",
                .cleared, nil,
                [
                    NowActionButton(label: "Full Report",   icon: "doc.richtext.fill"),
                    NowActionButton(label: "Share Summary", icon: "square.and.arrow.up"),
                ]
            )
        }

        if lower.contains("discovery") || lower.contains("scan") || lower.contains("indexed") {
            return (
                "Last scan: Today 06:14 AM\n\n4,283 files indexed\n342 flagged as sensitive\n28 classified as Restricted\n4 contain unredacted PII",
                .cleared, nil,
                [
                    NowActionButton(label: "View PII Files",  icon: "doc.text.magnifyingglass"),
                    NowActionButton(label: "Export Manifest", icon: "arrow.down.doc"),
                ]
            )
        }

        return (
            "I can help with file risk analysis, compliance reporting, external sharing review, DLP policy enforcement, or security summaries. What would you like to explore?",
            .cleared, nil,
            [NowActionButton(label: "View Insights", icon: "sparkles")]
        )
    }
}

// MARK: - Supporting Views

private struct SecurityPill: View {
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
                .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 0.5))
        )
    }
}

private struct NowInsightCard: View {
    let insight: NowAIInsight
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: insight.icon)
                    .font(.system(size: 15))
                    .foregroundColor(insight.color)
                    .frame(width: 20)
                Text(insight.text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text(insight.actionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                    .fixedSize()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct NowSuggestionChip: View {
    let label: String
    let icon: String
    let brandBlue: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(brandBlue)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(brandBlue.opacity(0.07))
                    .overlay(Capsule().stroke(brandBlue.opacity(0.2), lineWidth: 0.75))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct NowTypingDotsView: View {
    @State private var dots: [CGFloat] = [1, 1, 1]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(Color.secondary).frame(width: 7, height: 7)
                    .scaleEffect(dots[i])
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        .onAppear {
            for i in 0..<3 {
                withAnimation(
                    .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
                ) { dots[i] = 0.4 }
            }
        }
    }
}

// MARK: - Button Styles

private struct NowOutlinePillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct NowFilledPillStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(color))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Activity Sheet

private struct ActivitySheet: View {
    @Binding var notifications: [AppNotification]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(notifications) { notif in
                    NowNotificationRow(notif: notif) { markRead(notif) }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparatorTint(Color(.systemGray5))
                }
            }
            .listStyle(.plain)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func markRead(_ notif: AppNotification) {
        guard let idx = notifications.firstIndex(where: { $0.id == notif.id }) else { return }
        let n = notifications[idx]
        notifications[idx] = AppNotification(
            id: n.id, icon: n.icon, color: n.color,
            title: n.title, body: n.body, timeAgo: n.timeAgo,
            category: n.category, isRead: true
        )
    }
}

// MARK: - Notification Row

private struct NowNotificationRow: View {
    let notif: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(notif.color.opacity(0.12)).frame(width: 40, height: 40)
                    Image(systemName: notif.icon)
                        .font(.system(size: 16))
                        .foregroundColor(notif.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notif.title)
                            .font(.system(size: 14, weight: notif.isRead ? .regular : .semibold))
                            .foregroundColor(notif.isRead ? .secondary : .primary)
                        Spacer()
                        Text(notif.timeAgo)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Text(notif.body)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !notif.isRead {
                    Circle()
                        .fill(Color(red: 0.239, green: 0.353, blue: 0.996))
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Models

enum NotifCategory: String, CaseIterable {
    case security = "Security"
    case sharing  = "Sharing"
    case email    = "Email"
    case system   = "System"

    var label: String { rawValue }
}

struct AppNotification: Identifiable {
    let id: UUID
    let icon: String
    let color: Color
    let title: String
    let body: String
    let timeAgo: String
    let category: NotifCategory
    let isRead: Bool

    var destinationTab: AppCoordinator.AppTab? {
        switch category {
        case .security: return .files
        case .sharing:  return .files
        case .email:    return .messages
        case .system:   return nil
        }
    }

    static let samples: [AppNotification] = [
        AppNotification(id: UUID(), icon: "exclamationmark.triangle.fill", color: .red,
                        title: "Phishing Detected",
                        body: "High-risk email from unknown sender flagged in your inbox.",
                        timeAgo: "5m ago", category: .security, isRead: false),
        AppNotification(id: UUID(), icon: "arrow.up.forward.circle.fill",
                        color: Color(red: 0.239, green: 0.353, blue: 0.996),
                        title: "Share Expiring Soon",
                        body: "Patient-Records-2025.pdf link expires in 24 hours.",
                        timeAgo: "1h ago", category: .sharing, isRead: false),
        AppNotification(id: UUID(), icon: "eye.fill", color: .blue,
                        title: "File Accessed",
                        body: "Sarah Chen viewed Q4-Financial-Report.xlsx via your share link.",
                        timeAgo: "2h ago", category: .sharing, isRead: false),
        AppNotification(id: UUID(), icon: "lock.fill", color: .green,
                        title: "Encryption Complete",
                        body: "3 newly imported files have been encrypted and classified.",
                        timeAgo: "4h ago", category: .system, isRead: true),
        AppNotification(id: UUID(), icon: "envelope.badge.fill", color: .orange,
                        title: "Sensitive Email",
                        body: "Incoming message from legal@acme.com classified as Confidential.",
                        timeAgo: "6h ago", category: .email, isRead: true),
        AppNotification(id: UUID(), icon: "shield.slash.fill", color: .red,
                        title: "Policy Block",
                        body: "External share attempt for restricted file was blocked.",
                        timeAgo: "1d ago", category: .security, isRead: true),
        AppNotification(id: UUID(), icon: "tag.fill", color: .purple,
                        title: "Auto-Classification",
                        body: "2 files reclassified to Restricted based on new PHI scan.",
                        timeAgo: "2d ago", category: .system, isRead: true),
    ]
}

#Preview {
    NowTabView()
        .environmentObject(AppCoordinator())
}
