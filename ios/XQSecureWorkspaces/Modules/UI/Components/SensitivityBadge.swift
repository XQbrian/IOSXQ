import SwiftUI
import XQCore

struct SensitivityBadge: View {
    let sensitivity: SensitivityLevel

    private var colors: (dot: Color, text: Color, background: Color) {
        switch sensitivity {
        case .public_:
            return (
                dot: Color(red: 0.180, green: 0.490, blue: 0.196),
                text: Color(red: 0.106, green: 0.369, blue: 0.125),
                background: Color(red: 0.910, green: 0.961, blue: 0.914)
            )
        case .internal_:
            return (
                dot: Color(red: 0.082, green: 0.396, blue: 0.753),
                text: Color(red: 0.051, green: 0.278, blue: 0.631),
                background: Color(red: 0.890, green: 0.949, blue: 0.992)
            )
        case .confidential:
            return (
                dot: Color(red: 0.961, green: 0.498, blue: 0.090),
                text: Color(red: 0.427, green: 0.298, blue: 0.000),
                background: Color(red: 1.000, green: 0.973, blue: 0.882)
            )
        case .restricted:
            return (
                dot: Color(red: 0.776, green: 0.157, blue: 0.157),
                text: Color(red: 0.482, green: 0.000, blue: 0.200),
                background: Color(red: 0.988, green: 0.894, blue: 0.925)
            )
        }
    }

    private var label: String {
        switch sensitivity {
        case .public_: return "PUBLIC"
        case .internal_: return "INTERNAL"
        case .confidential: return "CONFIDENTIAL"
        case .restricted: return "RESTRICTED"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(colors.dot)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.4)
        }
        .foregroundColor(colors.text)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(colors.background)
        )
    }
}

#Preview {
    VStack(spacing: 8) {
        SensitivityBadge(sensitivity: .public_)
        SensitivityBadge(sensitivity: .internal_)
        SensitivityBadge(sensitivity: .confidential)
        SensitivityBadge(sensitivity: .restricted)
    }
    .padding()
}
