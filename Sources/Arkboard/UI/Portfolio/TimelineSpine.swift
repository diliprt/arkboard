import SwiftUI

struct TimelineEvent: Identifiable {
    var id: String
    var date: Date
    var title: String
    var detail: String
    var identifiers: [String]
    var hue: Hue
    var isMilestone: Bool
}

struct TimelineSpine: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var events: [TimelineEvent]
    var showToday: Bool = true

    var body: some View {
        let ordered = events.sorted { $0.date < $1.date }
        if ordered.isEmpty {
            EmptyStateView(section: .timeline, title: EmptyCopy.noTimeline.0, sentence: EmptyCopy.noTimeline.1)
        } else {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(weeks(ordered), id: \.start) { week in
                        Text(RelativeTime.weekHeader(week.start).uppercased())
                            .font(type.caption)
                            .foregroundStyle(Hue.moss.color(for: scheme))
                            .padding(.vertical, 8)
                        ForEach(week.events) { event in
                            if showToday, shouldShowToday(before: event, in: week.events) {
                                todayRule
                            }
                            eventRow(event)
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo("today", anchor: .center)
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
                Text(event.title)
                    .font(event.isMilestone ? type.bodyStrong : type.body)
                Text(event.date, style: .date)
                    .font(type.caption)
                    .foregroundStyle(StudioColor.secondary)
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(type.callout)
                        .foregroundStyle(StudioColor.secondary)
                        .lineLimit(1)
                }
                HStack {
                    ForEach(event.identifiers, id: \.self) { ident in
                        Chip(text: ident, hue: .teal, mono: true)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func weeks(_ events: [TimelineEvent]) -> [(start: Date, events: [TimelineEvent])] {
        let calendar = Calendar.current
        var groups: [(Date, [TimelineEvent])] = []
        for event in events {
            let start = calendar.dateInterval(of: .weekOfYear, for: event.date)?.start ?? event.date
            if let index = groups.firstIndex(where: { Calendar.current.isDate($0.0, inSameDayAs: start) }) {
                groups[index].1.append(event)
            } else {
                groups.append((start, [event]))
            }
        }
        return groups
    }

    private func shouldShowToday(before event: TimelineEvent, in events: [TimelineEvent]) -> Bool {
        let now = Date()
        guard event.date >= now else { return false }
        return events.first(where: { $0.date >= now })?.id == event.id
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
                        title: "\(issue.identifier)  \(issue.title)",
                        detail: "",
                        identifiers: [issue.identifier],
                        hue: .moss,
                        isMilestone: false
                    )
                )
            }
        }
        return items
    }
}
