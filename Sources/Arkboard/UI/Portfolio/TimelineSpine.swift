import SwiftUI

struct TimelineEvent: Identifiable, Equatable {
    var id: String
    var date: Date
    var title: String
    var detail: String
    var identifiers: [String]
    var hue: Hue
    var isMilestone: Bool
    var identifier: String? = nil
}

enum TimelinePlacement {
    enum Item: Identifiable, Equatable {
        case today
        case week(Date)
        case event(TimelineEvent)

        var id: String {
            switch self {
            case .today: return "today"
            case .week(let start): return "week-\(start.timeIntervalSince1970)"
            case .event(let event): return event.id
            }
        }
    }

    /// Index of the single Today rule: before the first future event.
    static func todayIndex(in dates: [Date], now: Date) -> Int {
        dates.firstIndex { $0 > now } ?? dates.count
    }

    static func items(events: [TimelineEvent], now: Date = Date(), showToday: Bool = true) -> [Item] {
        let ordered = events.sorted { $0.date < $1.date }
        let insertAt = todayIndex(in: ordered.map(\.date), now: now)
        var result: [Item] = []
        var lastWeek: Date?
        let calendar = Calendar.current
        for (index, event) in ordered.enumerated() {
            if showToday, index == insertAt {
                result.append(.today)
            }
            let start = calendar.dateInterval(of: .weekOfYear, for: event.date)?.start ?? event.date
            if lastWeek == nil || !calendar.isDate(start, inSameDayAs: lastWeek!) {
                result.append(.week(start))
                lastWeek = start
            }
            result.append(.event(event))
        }
        if showToday, insertAt == ordered.count {
            result.append(.today)
        }
        return result
    }
}

struct TimelineSpine: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var events: [TimelineEvent]
    var showToday: Bool = true

    var body: some View {
        let items = TimelinePlacement.items(events: events, showToday: showToday)
        if events.isEmpty {
            EmptyStateView(section: .timeline, title: EmptyCopy.noTimeline.0, sentence: EmptyCopy.noTimeline.1, minHeight: Metrics.emptyPaneMin)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    switch item {
                    case .today:
                        todayRule
                    case .week(let start):
                        Text(RelativeTime.weekHeader(start).uppercased())
                            .font(type.caption)
                            .foregroundStyle(Hue.moss.color(for: scheme))
                            .padding(.vertical, 8)
                    case .event(let event):
                        eventRow(event)
                    }
                }
            }
        }
    }

    private var todayRule: some View {
        HStack {
            Rectangle().fill(Hue.moss.color(for: scheme)).frame(height: 1)
            Text("Today")
                .font(type.caption)
                .foregroundStyle(Hue.moss.color(for: scheme))
            Rectangle().fill(Hue.moss.color(for: scheme)).frame(height: 1)
        }
        .id("today")
        .padding(.vertical, 8)
    }

    private func eventRow(_ event: TimelineEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(event.hue.color(for: scheme))
                .frame(width: event.isMilestone ? 10 : 6, height: event.isMilestone ? 10 : 6)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let identifier = event.identifier {
                        Text(identifier)
                            .font(type.mono)
                            .foregroundStyle(StudioColor.secondary)
                    }
                    Text(event.title)
                        .font(event.isMilestone ? type.bodyStrong : type.body)
                }
                Text(event.date, style: .date)
                    .font(type.caption)
                    .foregroundStyle(StudioColor.secondary)
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(type.callout)
                        .foregroundStyle(StudioColor.secondary)
                        .lineLimit(1)
                }
                if !event.identifiers.isEmpty {
                    HStack {
                        ForEach(event.identifiers, id: \.self) { ident in
                            Chip(text: ident, hue: .teal, mono: true)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

enum TimelineBuilder {
    static func events(milestones: [Milestone], issues: [Issue]) -> [TimelineEvent] {
        var items: [TimelineEvent] = []
        for milestone in milestones {
            let hue: Hue
            switch milestone.status {
            case .done: hue = .moss
            case .inProgress: hue = .gold
            case .missed: hue = .crimson
            case .planned: hue = .slate
            }
            items.append(
                TimelineEvent(
                    id: milestone.id,
                    date: milestone.targetDate,
                    title: milestone.title,
                    detail: milestone.bodyMarkdown,
                    identifiers: milestone.relatedIdentifiers,
                    hue: hue,
                    isMilestone: true
                )
            )
        }
        for issue in issues where issue.status == .done {
            if let completed = issue.completedAt {
                items.append(
                    TimelineEvent(
                        id: issue.id,
                        date: completed,
                        title: issue.title,
                        detail: "",
                        identifiers: [],
                        hue: .moss,
                        isMilestone: false,
                        identifier: issue.identifier
                    )
                )
            }
        }
        return items
    }
}
