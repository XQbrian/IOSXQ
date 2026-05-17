import SwiftUI

struct FileRowView: View {
    let file: SecureFile

    private var fileExtension: String {
        (file.name as NSString).pathExtension.lowercased()
    }

    private var iconInfo: (label: String, gradient: LinearGradient) {
        switch fileExtension {
        case "pdf":
            return (
                "PDF",
                LinearGradient(
                    colors: [Color(red: 1.000, green: 0.231, blue: 0.188), Color(red: 1.000, green: 0.420, blue: 0.420)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        case "docx", "doc":
            return (
                "DOC",
                LinearGradient(
                    colors: [Color(red: 0.169, green: 0.361, blue: 0.902), Color(red: 0.290, green: 0.486, blue: 0.969)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        case "xlsx", "xls":
            return (
                "XLS",
                LinearGradient(
                    colors: [Color(red: 0.106, green: 0.541, blue: 0.306), Color(red: 0.204, green: 0.780, blue: 0.349)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        case "pptx", "ppt":
            return (
                "PPT",
                LinearGradient(
                    colors: [Color(red: 0.910, green: 0.306, blue: 0.106), Color(red: 1.000, green: 0.439, blue: 0.263)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        default:
            return (
                "FILE",
                LinearGradient(
                    colors: [Color(red: 0.557, green: 0.557, blue: 0.576), Color(red: 0.682, green: 0.682, blue: 0.698)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        }
    }

    private var formattedSize: String {
        let bytes = file.sizeBytes
        if bytes >= 1_048_576 {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.1f MB", mb)
        } else if bytes >= 1024 {
            let kb = Double(bytes) / 1024
            return String(format: "%.0f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(file.modifiedAt) {
            return "Today"
        } else if calendar.isDateInYesterday(file.modifiedAt) {
            return "Yesterday"
        } else {
            let diff = calendar.dateComponents([.day], from: file.modifiedAt, to: Date())
            if let days = diff.day, days < 7 {
                return "\(days) days ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: file.modifiedAt)
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(iconInfo.gradient)
                .frame(width: 40, height: 48)
                .overlay(
                    Text(iconInfo.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("\(formattedSize) · \(formattedDate)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SensitivityBadge(sensitivity: file.sensitivity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
