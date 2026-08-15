import SwiftUI

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
}

enum TimelineCalendarMath {
    static func periodStart(containing date: Date, scale: TimelineScale, calendar: Calendar = .current) -> Date {
        switch scale {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        case .year:
            return calendar.dateInterval(of: .year, for: date)?.start ?? date
        }
    }

    static func shift(_ start: Date, scale: TimelineScale, by delta: Int, calendar: Calendar = .current) -> Date {
        switch scale {
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: delta, to: start) ?? start
        case .month:
            return calendar.date(byAdding: .month, value: delta, to: start) ?? start
        case .year:
            return calendar.date(byAdding: .year, value: delta, to: start) ?? start
        }
    }

    static func title(_ start: Date, scale: TimelineScale, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        switch scale {
        case .week:
            formatter.dateFormat = "d MMMM"
            return "Week of \(formatter.string(from: start))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: start)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: start)
        }
    }

    static func daysInWeek(starting start: Date, calendar: Calendar = .current) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func monthGrid(starting start: Date, calendar: Calendar = .current) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: start) else { return [] }
        let days = calendar.range(of: .day, in: .month, for: start)?.count ?? 0
        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in 0..<days {
            cells.append(calendar.date(byAdding: .day, value: day, to: interval.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    static func monthsInYear(starting start: Date, calendar: Calendar = .current) -> [Date] {
        (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
    }
}

struct TimelineCalendarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var projectId: String?
    @State private var scale: TimelineScale = .month
    @State private var anchor = Date()

    private var periodStart: Date {
        TimelineCalendarMath.periodStart(containing: anchor, scale: scale)
    }

    private var events: [TimelineEvent] {
        let all = TimelineBuilder.events(milestones: store.milestones, issues: store.issues.filter { $0.status == .done })
        if let projectId {
            return all.filter { $0.projectId == projectId }
        }
        return all
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            controls
            switch scale {
            case .week: weekGrid
            case .month: monthGrid
            case .year: yearGrid
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .chiefOfStaffContextMenu()
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("Scale", selection: $scale) {
                ForEach(TimelineScale.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            Button {
                anchor = TimelineCalendarMath.shift(periodStart, scale: scale, by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            Text(TimelineCalendarMath.title(periodStart, scale: scale))
                .font(type.heading)
            Button {
                anchor = TimelineCalendarMath.shift(periodStart, scale: scale, by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            Button("Today") { anchor = Date() }
                .buttonStyle(.plain)
                .font(type.caption)
            Spacer()
        }
        .onChange(of: scale) { _, _ in
            anchor = TimelineCalendarMath.periodStart(containing: anchor, scale: scale)
        }
    }

    private var weekGrid: some View {
        let days = TimelineCalendarMath.daysInWeek(starting: periodStart)
        return HStack(alignment: .top, spacing: 8) {
            ForEach(days, id: \.self) { day in
                dayColumn(day, compact: false)
            }
        }
    }

    private var monthGrid: some View {
        let cells = TimelineCalendarMath.monthGrid(starting: periodStart)
        let symbols = weekdaySymbols
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(type.caption)
                        .foregroundStyle(StudioColor.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayColumn(day, compact: true)
                    } else {
                        Color.clear.frame(minHeight: 72)
                    }
                }
            }
        }
    }

    private var yearGrid: some View {
        let months = TimelineCalendarMath.monthsInYear(starting: periodStart)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "MMMM"
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 360), spacing: 12)], spacing: 12) {
            ForEach(months, id: \.self) { month in
                let monthEvents = events.filter { Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month) }
                VStack(alignment: .leading, spacing: 8) {
                    Text(formatter.string(from: month)).font(type.bodyStrong)
                    if monthEvents.isEmpty {
                        Text("—")
                            .font(type.caption)
                            .foregroundStyle(StudioColor.tertiary)
                    } else {
                        ForEach(monthEvents) { event in
                            eventChip(event)
                        }
                    }
                }
                .padding(Metrics.cardPad)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioColor.card, in: RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
            }
        }
    }

    private func dayColumn(_ day: Date, compact: Bool) -> some View {
        let dayEvents = events.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
        let isToday = Calendar.current.isDateInToday(day)
        return VStack(alignment: .leading, spacing: 6) {
            Text(day, format: .dateTime.day())
                .font(type.caption)
                .foregroundStyle(isToday ? Hue.moss.color(for: scheme) : StudioColor.secondary)
            ForEach(dayEvents) { event in
                eventChip(event)
            }
            if dayEvents.isEmpty && !compact {
                Spacer(minLength: 24)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: compact ? 72 : 160, alignment: .topLeading)
        .background(
            StudioColor.card.opacity(isToday ? 1 : 0.7),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isToday ? Hue.moss.color(for: scheme).opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    private func eventChip(_ event: TimelineEvent) -> some View {
        Button {
            if let id = event.projectId {
                store.openProjectTimeline(id)
            }
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Circle()
                    .fill(event.hue.color(for: scheme))
                    .frame(width: event.isMilestone ? 8 : 6, height: event.isMilestone ? 8 : 6)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    if projectId == nil, let id = event.projectId, let project = store.project(id: id) {
                        HStack(spacing: 4) {
                            ProjectIcon(project: project, imageData: store.markImage(for: project), size: 14)
                            Text(project.name).font(type.caption)
                        }
                    }
                    Text(event.title)
                        .font(event.isMilestone ? type.bodyStrong : type.caption)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(event.projectId == nil)
        .contextMenu { ChiefOfStaffMenuButton(selectedText: FocusedSelection.currentText()) }
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...]) + Array(symbols[..<start])
    }
}
