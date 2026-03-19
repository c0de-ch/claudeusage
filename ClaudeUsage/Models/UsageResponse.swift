import Foundation
import SwiftUI

struct UsageResponse: Codable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDayOpus: UsageWindow?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case extraUsage = "extra_usage"
    }
}

struct UsageWindow: Codable {
    let resetsAt: String?
    let utilization: Double

    enum CodingKeys: String, CodingKey {
        case resetsAt = "resets_at"
        case utilization
    }

    var resetDate: Date? {
        guard let resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: resetsAt) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }

    var percentage: Int {
        Int(utilization.rounded())
    }

    var normalizedValue: Double {
        min(max(utilization / 100.0, 0), 1)
    }

    var statusColor: Color {
        switch utilization {
        case ..<50: return .green
        case 50..<80: return .yellow
        default: return .red
        }
    }

    var countdownString: String? {
        guard let resetDate else { return nil }
        return TimeFormatting.countdown(to: resetDate)
    }
}

struct ExtraUsage: Codable {
    let hasPurchased: Bool?

    enum CodingKeys: String, CodingKey {
        case hasPurchased = "has_purchased"
    }
}
