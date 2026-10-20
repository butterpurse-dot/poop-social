import Foundation

enum Format {

    /// Compact relative time: now, 4m, 3h, 2d, 5w.
    static func ago(_ date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60:        return "now"
        case ..<3_600:     return "\(Int(seconds / 60))m"
        case ..<86_400:    return "\(Int(seconds / 3_600))h"
        case ..<604_800:   return "\(Int(seconds / 86_400))d"
        case ..<2_419_200: return "\(Int(seconds / 604_800))w"
        default:           return "\(Int(seconds / 2_419_200))mo"
        }
    }

    /// 1200 → 1.2k
    static func compact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fm", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return "\(value)"
    }

    static func wait(_ minutes: Int) -> String {
        switch minutes {
        case 0:        return "No wait"
        case 1...15:   return "\(minutes) min"
        default:       return "\(minutes)+ min"
        }
    }
}
