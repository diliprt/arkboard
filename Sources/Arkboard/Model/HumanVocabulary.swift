import Foundation

/// Agent-facing status becomes three human groups. The group is the only status a human sees.
enum HumanIssueGroup: String, CaseIterable, Sendable {
    case underway = "Underway"
    case queued = "Queued"
    case done = "Done"
    case archived = "Archived"

    static func group(for issue: Issue) -> HumanIssueGroup? {
        if issue.archivedAt != nil { return .archived }
        switch issue.status {
        case .inProgress: return .underway
        case .backlog, .todo: return .queued
        case .done: return .done
        case .canceled: return nil
        }
    }

    static func matches(_ status: IssueStatus, group: HumanIssueGroup) -> Bool {
        switch group {
        case .underway: return status == .inProgress
        case .queued: return status == .backlog || status == .todo
        case .done: return status == .done
        case .archived: return false
        }
    }
}

enum RelativeTime {
    static func format(_ date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 45 { return "just now" }
        if seconds < 3600 { return "\(max(1, Int(seconds / 60)))m ago" }
        if seconds < 86_400 { return "\(max(1, Int(seconds / 3600)))h ago" }
        if seconds < 86_400 * 14 { return "\(max(1, Int(seconds / 86_400)))d ago" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    static func dayHeader(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }

    static func weekHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMMM"
        return "Week of \(formatter.string(from: start))"
    }
}

enum StudioISO8601 {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func string(from date: Date) -> String {
        fractional.string(from: date)
    }

    static func date(from string: String) -> Date? {
        if let date = fractional.date(from: string) { return date }
        return plain.date(from: string)
    }
}
