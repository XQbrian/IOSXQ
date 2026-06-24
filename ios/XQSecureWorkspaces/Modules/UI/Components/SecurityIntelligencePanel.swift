import SwiftUI
import XQCore

// MARK: - Security & Intelligence Panel

/// Unified expandable/minimizable security panel — replaces all fragmented security info panels.
/// Persists expanded/minimized state globally via AppStorage so user preference is remembered across files.
struct SecurityIntelligencePanel: View {
    let sensitivity: SensitivityLevel
    let sections: [SIPSection]
    var theme: SIPTheme = .dark

    @AppStorage("xq.sip.minimized") private var isMinimized = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if !isMinimized {
                ForEach(sections) { section in
                    Divider()
                        .background(theme.separatorColor)
                    SIPSectionView(section: section, theme: theme)
                }
            } else {
                minimizedBar
            }
        }
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(theme.borderColor, lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(sensitivity.sipIconBackground)
                    .frame(width: 22, height: 22)
                Image(systemName: AppIcon.shield)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(sensitivity.sipIconColor)
            }

            Text("Security & Intelligence")
                .font(.system(size: 11, weight: .bold))
                .kerning(0.3)
                .textCase(.uppercase)
                .foregroundColor(theme.titleColor)

            Spacer()

            SensitivityDot(sensitivity: sensitivity)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isMinimized.toggle()
                }
            } label: {
                Text(isMinimized ? "Expand" : "Minimize")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.toggleColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(theme.toggleBackground)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if isMinimized {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isMinimized = false
                }
            }
        }
    }

    // MARK: - Minimized bar

    private var minimizedBar: some View {
        HStack(spacing: 7) {
            Image(systemName: AppIcon.lock)
                .font(.system(size: 10))
                .foregroundColor(sensitivity.sipIconColor)

            Text(sensitivity.minimizedLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.titleColor)

            Spacer()

            if sections.contains(where: { $0.hasHighRiskItem }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("Risk detected")
                        .font(.system(size: 10))
                        .foregroundColor(Color.red)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
    }
}

// MARK: - SIP Section

struct SIPSectionView: View {
    let section: SIPSection
    let theme: SIPTheme
    @State private var isCollapsed: Bool

    init(section: SIPSection, theme: SIPTheme) {
        self.section = section
        self.theme = theme
        _isCollapsed = State(initialValue: section.defaultCollapsed)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(section.title)
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(0.3)
                        .textCase(.uppercase)
                        .foregroundColor(theme.sectionTitleColor)

                    if let badge = section.badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(section.badgeColor ?? theme.sectionTitleColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill((section.badgeColor ?? theme.sectionTitleColor).opacity(0.15))
                            )
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.sectionTitleColor.opacity(0.6))
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                section.content
                    .padding(.horizontal, 13)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - SIPSection Model

struct SIPSection: Identifiable {
    let id: String
    let title: String
    let badge: String?
    let badgeColor: Color?
    let defaultCollapsed: Bool
    let hasHighRiskItem: Bool
    let content: AnyView

    init(
        id: String,
        title: String,
        badge: String? = nil,
        badgeColor: Color? = nil,
        defaultCollapsed: Bool = false,
        hasHighRiskItem: Bool = false,
        @ViewBuilder content: () -> some View
    ) {
        self.id = id
        self.title = title
        self.badge = badge
        self.badgeColor = badgeColor
        self.defaultCollapsed = defaultCollapsed
        self.hasHighRiskItem = hasHighRiskItem
        self.content = AnyView(content())
    }
}

// MARK: - SIPTheme

enum SIPTheme {
    case dark   // File viewer (dark background)
    case light  // Email / light surfaces

    var background: Color {
        switch self {
        case .dark:  return Color(red: 0.051, green: 0.051, blue: 0.051)
        case .light: return Color(.secondarySystemBackground)
        }
    }

    var borderColor: Color {
        switch self {
        case .dark:  return Color(white: 0.16)
        case .light: return Color(.systemGray4)
        }
    }

    var separatorColor: Color {
        switch self {
        case .dark:  return Color(white: 0.14)
        case .light: return Color(.systemGray5)
        }
    }

    var titleColor: Color {
        switch self {
        case .dark:  return .white
        case .light: return .primary
        }
    }

    var sectionTitleColor: Color {
        switch self {
        case .dark:  return Color(white: 0.55)
        case .light: return .secondary
        }
    }

    var toggleColor: Color {
        switch self {
        case .dark:  return Color(white: 0.75)
        case .light: return .secondary
        }
    }

    var toggleBackground: Color {
        switch self {
        case .dark:  return Color(white: 0.18)
        case .light: return Color(.systemGray5)
        }
    }

    var bodyTextColor: Color {
        switch self {
        case .dark:  return Color(white: 0.75)
        case .light: return .primary
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .dark:  return Color(white: 0.45)
        case .light: return .secondary
        }
    }
}

// MARK: - Sensitivity helpers

private struct SensitivityDot: View {
    let sensitivity: SensitivityLevel

    var body: some View {
        Circle()
            .fill(sensitivity.dotColor)
            .frame(width: 7, height: 7)
    }
}

extension SensitivityLevel {
    var dotColor: Color {
        switch self {
        case .public_:      return Color(red: 0.204, green: 0.780, blue: 0.349)
        case .internal_:    return Color(red: 0.239, green: 0.353, blue: 0.996)
        case .confidential: return Color(red: 1.000, green: 0.584, blue: 0.000)
        case .restricted:   return Color(red: 1.000, green: 0.231, blue: 0.188)
        }
    }

    var sipIconBackground: Color { dotColor.opacity(0.18) }
    var sipIconColor: Color { dotColor }

    var minimizedLabel: String {
        switch self {
        case .public_:      return "PUBLIC"
        case .internal_:    return "INTERNAL — DO NOT DISTRIBUTE"
        case .confidential: return "CONFIDENTIAL — INTERNAL USE ONLY"
        case .restricted:   return "RESTRICTED — PHI DETECTED"
        }
    }
}

// MARK: - Reusable SIP row types

struct SIPInfoRow: View {
    let label: String
    let value: String
    let valueColor: Color?
    let theme: SIPTheme

    init(label: String, value: String, valueColor: Color? = nil, theme: SIPTheme = .dark) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.theme = theme
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryTextColor)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(valueColor ?? theme.bodyTextColor)
        }
        .padding(.vertical, 3)
    }
}

struct SIPTagRow: View {
    let tags: [SIPTag]
    let theme: SIPTheme

    var body: some View {
        SIPFlowLayout(spacing: 6) {
            ForEach(tags) { tag in
                Text(tag.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(tag.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(tag.color.opacity(0.15))
                    )
            }
        }
    }
}

struct SIPTag: Identifiable {
    let id = UUID()
    let label: String
    let color: Color
}

// MARK: - FlowLayout (wrapping tag cloud)

struct SIPFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
            .reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var rowWidth: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth && !rows.last!.isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(view)
            rowWidth += size.width + spacing
        }
        return rows
    }
}
