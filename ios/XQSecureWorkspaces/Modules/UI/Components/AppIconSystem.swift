import SwiftUI

// MARK: - Icon sizes

enum AppIconSize: CGFloat {
    case nav    = 22
    case action = 18
    case sm     = 14
    case xs     = 11
}

// MARK: - Icon semantic colors

enum AppIconColor {
    case neutral, info, warning, critical, safe, ai

    var color: Color {
        switch self {
        case .neutral:  return Color(.secondaryLabel)
        case .info:     return Color(red: 0.239, green: 0.353, blue: 0.996)
        case .warning:  return Color(red: 1.0, green: 0.584, blue: 0.0)
        case .critical: return Color(red: 1.0, green: 0.231, blue: 0.188)
        case .safe:     return Color(red: 0.204, green: 0.780, blue: 0.349)
        case .ai:       return Color(red: 0.686, green: 0.322, blue: 0.871)
        }
    }
}

// MARK: - Icon name catalog

enum AppIcon {
    // Navigation — outlined (inactive) / filled (active)
    static let files          = "folder"
    static let filesFill      = "folder.fill"
    static let messages       = "envelope"
    static let messagesFill   = "envelope.fill"
    static let alerts         = "bell"
    static let alertsFill     = "bell.fill"
    static let ai             = "sparkles"
    static let settings       = "gearshape"
    static let settingsFill   = "gearshape.fill"

    // Security
    static let lock           = "lock.fill"
    static let shield         = "lock.shield.fill"
    static let blocked        = "nosign"
    static let verified       = "checkmark.shield.fill"
    static let warning        = "exclamationmark.triangle.fill"
    static let info           = "info.circle"
    static let phi            = "cross.case.fill"

    // Files & folders
    static let file           = "doc"
    static let fileFill       = "doc.fill"
    static let folder         = "folder"
    static let folderFill     = "folder.fill"
    static let folderPlus     = "folder.badge.plus"
    static let archive        = "archivebox.fill"

    // Actions
    static let share          = "square.and.arrow.up"
    static let tag            = "tag.fill"
    static let merge          = "arrow.triangle.merge"
    static let classify       = "sparkles"
    static let semanticSearch = "sparkles.magnifyingglass"
    static let riskDashboard  = "shield.lefthalf.filled.badge.checkmark"
    static let download       = "arrow.down.circle.fill"
    static let eye            = "eye.fill"
    static let trash          = "trash.fill"
    static let add            = "plus"

    // People
    static let person         = "person.fill"
    static let group          = "person.2.fill"

    // Workspace types
    static let vault          = "lock.shield.fill"
    static let legal          = "building.columns.fill"
    static let briefcase      = "briefcase.fill"
    static let health         = "cross.case.fill"
    static let research       = "flask.fill"
    static let engineering    = "cpu.fill"
    static let compliance     = "checkmark.seal.fill"
}

// MARK: - XQIcon view

struct XQIcon: View {
    let name: String
    var size: CGFloat = AppIconSize.action.rawValue
    var color: Color = AppIconColor.neutral.color
    var weight: Font.Weight = .semibold

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
            .foregroundColor(color)
    }
}

// MARK: - XQIconBadge view (icon inside a flat tinted rounded-rect container)

struct XQIconBadge: View {
    let name: String
    var iconSize: CGFloat = AppIconSize.action.rawValue
    var iconColor: Color
    var background: Color
    var containerSize: CGFloat = 36
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(background)
                .frame(width: containerSize, height: containerSize)
            Image(systemName: name)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(iconColor)
        }
    }
}
