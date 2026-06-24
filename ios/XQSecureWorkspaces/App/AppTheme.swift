import SwiftUI

enum AppThemeMode: String, CaseIterable {
    case light, dark, earth

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark:  return "Dark"
        case .earth: return "Earth"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light:        return .light
        case .dark, .earth: return .dark
        }
    }

    var brandColor: Color {
        self == .earth
            ? Color(red: 1.0, green: 0.478, blue: 0.349)  // #FF7A59
            : Color(red: 0.239, green: 0.353, blue: 0.996) // XQ blue
    }

    var swatchColors: (Color, Color) {
        switch self {
        case .light: return (Color(red: 0.949, green: 0.949, blue: 0.969),
                             Color(red: 0.239, green: 0.353, blue: 0.996))
        case .dark:  return (.black,
                             Color(red: 0.412, green: 0.471, blue: 0.973))
        case .earth: return (Color(red: 0.027, green: 0.063, blue: 0.075),
                             Color(red: 1.0, green: 0.478, blue: 0.349))
        }
    }
}

@MainActor
final class AppTheme: ObservableObject {
    private static let defaultsKey = "xq.appTheme"

    @Published var mode: AppThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.defaultsKey) }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? "light"
        mode = AppThemeMode(rawValue: raw) ?? .light
    }
}
