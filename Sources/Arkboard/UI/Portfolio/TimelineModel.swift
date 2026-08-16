import Foundation

/// Column granularity of the Gantt time axis. The shape is always bars on a timeline;
/// this only decides how wide one gridline column is.
enum TimelineScale: String, CaseIterable, Identifiable, Sendable {
    case week, month, year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    /// Below this a column label stops fitting, so the chart scrolls horizontally instead of squeezing.
    var minimumColumnWidth: Double {
        switch self {
        case .week: return 54
        case .month: return 88
        case .year: return 80
        }
    }

    /// A studio with one milestone still needs an axis wide enough to place Today against it.
    var minimumColumns: Int {
        switch self {
        case .week: return 6
        case .month: return 4
        case .year: return 3
        }
    }
}

/// The visible span of the axis, snapped outward to whole columns.
struct GanttWindow: Equatable, Sendable {
    var start: Date
    var end: Date

    var duration: TimeInterval { max(1, end.timeIntervalSince(start)) }
}

enum GanttMath {
    /// Monday-start Gregorian, so a week column is the same column on every machine.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }()

    static func columnStart(containing date: Date, scale: TimelineScale) -> Date {
        let day = calendar.startOfDay(for: date)
        switch scale {
        case .week:
            let weekday = calendar.component(.weekday, from: day)
            let back = (weekday - calendar.firstWeekday + 7) % 7
            return calendar.date(byAdding: .day, value: -back, to: day) ?? day
        case .month:
            let parts = calendar.dateComponents([.year, .month], from: day)
            return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1)) ?? day
        case .year:
            let parts = calendar.dateComponents([.year], from: day)
            return calendar.date(from: DateComponents(year: parts.year, month: 1, day: 1)) ?? day
        }
    }

    static func advance(_ start: Date, scale: TimelineScale, by delta: Int) -> Date {
        switch scale {
        case .week:
            return calendar.date(byAdding: .day, value: 7 * delta, to: start) ?? start
        case .month:
            return calendar.date(byAdding: .month, value: delta, to: start) ?? start
        case .year:
            return calendar.date(byAdding: .year, value: delta, to: start) ?? start
        }
    }

    static func columns(in window: GanttWindow, scale: TimelineScale) -> [Date] {
        var result: [Date] = []
        var cursor = columnStart(containing: window.start, scale: scale)
        while cursor < window.end, result.count < 512 {
            result.append(cursor)
            cursor = advance(cursor, scale: scale, by: 1)
        }
        if result.isEmpty {
            result = [columnStart(containing: window.start, scale: scale)]
        }
        return result
    }

    static func columnLabel(_ start: Date, scale: TimelineScale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_GB")
        switch scale {
        case .week:
            formatter.dateFormat = "d MMM"
            return formatter.string(from: start)
        case .month:
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: start)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: start)
        }
    }

    /// One padding column on each side so bars never sit flush against the frame,
    /// and always wide enough to hold Today.
    static func window(covering dates: [Date], scale: TimelineScale, now: Date = Date()) -> GanttWindow {
        var all = dates
        all.append(now)
        let first = all.min() ?? now
        let last = all.max() ?? now
        let start = columnStart(containing: advance(columnStart(containing: first, scale: scale), scale: scale, by: -1), scale: scale)
        var end = columnStart(containing: advance(columnStart(containing: last, scale: scale), scale: scale, by: 2), scale: scale)
        var count = columns(in: GanttWindow(start: start, end: end), scale: scale).count
        while count < scale.minimumColumns {
            end = advance(end, scale: scale, by: 1)
            count += 1
        }
        return GanttWindow(start: start, end: end)
    }

    /// Horizontal position of a date as 0…1 of the window.
    static func fraction(of date: Date, in window: GanttWindow) -> Double {
        let raw = date.timeIntervalSince(window.start) / window.duration
        return min(1, max(0, raw))
    }
}

/// Work the engine already dated — a completed issue — drawn as a light tick on a project bar.
struct GanttMark: Identifiable, Equatable, Sendable {
    var id: String
    var date: Date
    var title: String
    var identifier: String?
}

/// One line of the chart. Projects are the top level; milestones sit under their project.
struct GanttRow: Identifiable, Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case project
        case milestone
    }

    var id: String
    var kind: Kind
    var title: String
    var projectId: String?
    var projectKey: String?
    var projectColor: String?
    var start: Date
    var end: Date
    /// Milestone rows carry a diamond at their target date.
    var marker: Date?
    var status: MilestoneStatus?
    var dependsOn: [String] = []
    var relatedIdentifiers: [String] = []
    var marks: [GanttMark] = []
    var milestoneCount: Int = 0
}

/// A predecessor → successor edge between two milestone rows in the same chart.
struct GanttLink: Identifiable, Equatable, Sendable {
    var from: String
    var to: String

    var id: String { "\(from)->\(to)" }
}

struct GanttPlan: Equatable, Sendable {
    var rows: [GanttRow] = []
    var links: [GanttLink] = []
    var window: GanttWindow
    var scale: TimelineScale

    var isEmpty: Bool { rows.isEmpty }
}

struct GanttProjectInput: Equatable, Sendable {
    var id: String
    var key: String
    var name: String
    var color: String
}

struct GanttMilestoneInput: Equatable, Sendable {
    var id: String
    var projectId: String?
    var title: String
    var targetDate: Date
    var status: MilestoneStatus
    var dependsOn: [String] = []
    var relatedIdentifiers: [String] = []
}

struct GanttEventInput: Equatable, Sendable {
    var id: String
    var projectId: String
    var identifier: String
    var title: String
    var date: Date
}

enum GanttPlanner {
    /// Milestones with no project belong to the studio, not to a project row.
    static let studioRowId = "studio"
    static let studioRowTitle = "Studio"

    static func plan(
        projects: [GanttProjectInput],
        milestones: [GanttMilestoneInput],
        events: [GanttEventInput],
        scope: String? = nil,
        scale: TimelineScale = .month,
        now: Date = Date()
    ) -> GanttPlan {
        let scopedMilestones = milestones.filter { scope == nil || $0.projectId == scope }
        let scopedEvents = events.filter { scope == nil || $0.projectId == scope }
        let window = GanttMath.window(
            covering: scopedMilestones.map(\.targetDate) + scopedEvents.map(\.date),
            scale: scale,
            now: now
        )

        var targetById: [String: Date] = [:]
        for milestone in scopedMilestones {
            targetById[milestone.id] = milestone.targetDate
        }

        var buckets: [(key: String, project: GanttProjectInput?)] = projects
            .filter { scope == nil || $0.id == scope }
            .map { (key: $0.id, project: $0) }
        if scope == nil, scopedMilestones.contains(where: { $0.projectId == nil }) {
            buckets.append((key: studioRowId, project: nil))
        }

        var rows: [GanttRow] = []
        var links: [GanttLink] = []

        for bucket in buckets {
            let mine = scopedMilestones
                .filter { ($0.projectId ?? studioRowId) == bucket.key }
                .sorted { lhs, rhs in
                    lhs.targetDate == rhs.targetDate ? lhs.title < rhs.title : lhs.targetDate < rhs.targetDate
                }
            let marks = scopedEvents
                .filter { $0.projectId == bucket.key }
                .sorted { $0.date < $1.date }
                .map { GanttMark(id: $0.id, date: $0.date, title: $0.title, identifier: $0.identifier) }
            if mine.isEmpty, marks.isEmpty { continue }

            let dates = mine.map(\.targetDate) + marks.map(\.date)
            let projectStart = dates.min() ?? now
            let projectEnd = dates.max() ?? now

            rows.append(
                GanttRow(
                    id: bucket.project?.id ?? studioRowId,
                    kind: .project,
                    title: bucket.project?.name ?? studioRowTitle,
                    projectId: bucket.project?.id,
                    projectKey: bucket.project?.key,
                    projectColor: bucket.project?.color,
                    start: projectStart,
                    end: projectEnd,
                    marks: marks,
                    milestoneCount: mine.count
                )
            )

            for milestone in mine {
                // A milestone has one date. Its bar runs from whatever must finish first —
                // its predecessors, else the project's own start — to that date.
                let predecessors = milestone.dependsOn.filter { targetById[$0] != nil && $0 != milestone.id }
                let inherited = predecessors.compactMap { targetById[$0] }.max()
                var start = inherited ?? projectStart
                if start > milestone.targetDate {
                    start = milestone.targetDate
                }
                rows.append(
                    GanttRow(
                        id: milestone.id,
                        kind: .milestone,
                        title: milestone.title,
                        projectId: milestone.projectId,
                        projectKey: bucket.project?.key,
                        projectColor: bucket.project?.color,
                        start: start,
                        end: milestone.targetDate,
                        marker: milestone.targetDate,
                        status: milestone.status,
                        dependsOn: predecessors,
                        relatedIdentifiers: milestone.relatedIdentifiers
                    )
                )
                for predecessor in predecessors {
                    links.append(GanttLink(from: predecessor, to: milestone.id))
                }
            }
        }

        return GanttPlan(rows: rows, links: links, window: window, scale: scale)
    }
}

/// Dependency graph rules shared by the API and the store. Agents write these; humans read them.
enum GanttDependencies {
    static func normalise(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in raw {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    /// True when adding `candidates` as predecessors of `milestoneId` would close a loop.
    /// `edges` maps a milestone to the milestones it already depends on.
    static func createsCycle(milestoneId: String, candidates: [String], edges: [String: [String]]) -> Bool {
        var pending = candidates
        var seen = Set<String>()
        while let next = pending.popLast() {
            if next == milestoneId { return true }
            guard seen.insert(next).inserted else { continue }
            pending.append(contentsOf: edges[next] ?? [])
        }
        return false
    }
}
