import SwiftUI

struct RiskAlertCard: View {
    let title: String
    let description: String
    let actionLabel: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.165, green: 0.000, blue: 0.071)
            : Color(red: 0.988, green: 0.894, blue: 0.925)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color(red: 0.482, green: 0.000, blue: 0.200)
            : Color(red: 1.000, green: 0.804, blue: 0.824)
    }

    private var titleColor: Color {
        colorScheme == .dark
            ? Color(red: 1.000, green: 0.431, blue: 0.620)
            : Color(red: 0.714, green: 0.110, blue: 0.110)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("⚠️")
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(titleColor)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.239, green: 0.353, blue: 0.996))
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

#Preview {
    RiskAlertCard(
        title: "Policy Alert — Restricted File",
        description: "Q4-Financial-Report.pdf contains PHI detected by AI scanner. External share blocked.",
        actionLabel: "Review file →",
        action: {}
    )
    .padding()
}
