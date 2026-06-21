import Foundation

enum RelativeDateFormatting {
    static func agoLabel(for date: Date, relativeTo reference: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: reference)
    }
}