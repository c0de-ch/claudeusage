import Foundation

enum TimeFormatting {
    /// Formats a countdown to a future date as a compact string like "2h 34m" or "3d 8h"
    static func countdown(to date: Date, from now: Date = Date()) -> String? {
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return nil }

        let totalSeconds = Int(interval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formats a past date as a relative "last updated" string
    static func lastUpdated(_ date: Date, from now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)

        if interval < 5 {
            return "just now"
        } else if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}
