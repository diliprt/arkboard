import SwiftUI

/// The one timeline component. Rows are projects with their milestones underneath, bars sit on a
/// shared time axis, and dependency links run between milestones. The master Timeline passes no
/// scope; a project's Timeline tab passes its own id and gets the same chart, filtered.
/// Read-only: agents write milestones and dependencies through the API.
struct TimelineGanttView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var projectId: String?
    @State private var scale: TimelineScale = .month
    @State private var viewport: CGFloat = Metrics.documentMin

    private var plan: GanttPlan {
        GanttPlanner.plan(
            projects: TimelineBuilder.projects(store.projects),
            milestones: TimelineBuilder.milestones(store.milestones),
            events: TimelineBuilder.completedIssues(store.issues),
            scope: projectId,
            scale: scale
        )
    }

    var body: some View {
        let current = plan
        VStack(alignment: .leading, spacing: 14) {
            scaleControl
            if current.isEmpty {
                EmptyStateView(
                    section: .timeline,
                    title: EmptyCopy.noTimeline.0,
                    sentence: EmptyCopy.noTimeline.1,
                    minHeight: Metrics.emptyPaneMin
                )
            } else {
                chart(current)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .chiefOfStaffContextMenu()
    }

    private var scaleControl: some View {
        HStack(spacing: 12) {
            Picker("Scale", selection: $scale) {
                ForEach(TimelineScale.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 260)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Chart

    private func chart(_ plan: GanttPlan) -> some View {
        let columns = GanttMath.columns(in: plan.window, scale: plan.scale)
        let available = max(0, viewport - Metrics.ganttLabelColumn)
        let columnWidth = max(CGFloat(plan.scale.minimumColumnWidth), available / CGFloat(max(1, columns.count)))
        let plotWidth = columnWidth * CGFloat(columns.count)

        return HStack(alignment: .top, spacing: 0) {
            labelColumn(plan)
                .frame(width: Metrics.ganttLabelColumn, alignment: .leading)
            if plotWidth > available + 0.5 {
                ScrollView(.horizontal) {
                    plot(plan, columns: columns, columnWidth: columnWidth, width: plotWidth)
                }
            } else {
                plot(plan, columns: columns, columnWidth: columnWidth, width: plotWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: GanttViewportKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(GanttViewportKey.self) { width in
            viewport = width
        }
    }

    private func labelColumn(_ plan: GanttPlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: Metrics.ganttAxisHeight)
            ForEach(plan.rows) { row in
                rowLabel(row)
                    .frame(height: rowHeight(row), alignment: .leading)
            }
        }
    }

    private func plot(_ plan: GanttPlan, columns: [Date], columnWidth: CGFloat, width: CGFloat) -> some View {
        let height = plan.rows.reduce(CGFloat.zero) { $0 + rowHeight($1) }
        return VStack(alignment: .leading, spacing: 0) {
            axis(plan, columns: columns, columnWidth: columnWidth, width: width)
            ZStack(alignment: .topLeading) {
                gridlines(columns: columns, columnWidth: columnWidth, height: height)
                todayRule(plan, width: width, height: height)
                dependencyLinks(plan, width: width)
                VStack(spacing: 0) {
                    ForEach(plan.rows) { row in
                        barTrack(row, plan: plan, width: width)
                            .frame(width: width, height: rowHeight(row))
                    }
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
        .frame(width: width, alignment: .leading)
    }

    private func axis(_ plan: GanttPlan, columns: [Date], columnWidth: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 0) {
                ForEach(columns, id: \.self) { column in
                    Text(GanttMath.columnLabel(column, scale: plan.scale))
                        .font(type.caption)
                        .foregroundStyle(StudioColor.secondary)
                        .lineLimit(1)
                        .padding(.leading, 4)
                        .frame(width: columnWidth, alignment: .leading)
                }
            }
            todayFlag(plan, width: width)
        }
        .frame(width: width, height: Metrics.ganttAxisHeight, alignment: .bottomLeading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(StudioColor.hairline).frame(height: 1)
        }
    }

    private func gridlines(columns: [Date], columnWidth: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, _ in
                Rectangle()
                    .fill(index == 0 ? Color.clear : StudioColor.hairline.opacity(0.6))
                    .frame(width: 1, height: height)
                    .frame(width: columnWidth, alignment: .leading)
            }
        }
        .allowsHitTesting(false)
    }

    /// One Today rule for the whole chart, positioned on the axis rather than between rows.
    @ViewBuilder
    private func todayRule(_ plan: GanttPlan, width: CGFloat, height: CGFloat) -> some View {
        if let x = todayOffset(plan, width: width) {
            Rectangle()
                .fill(Hue.moss.color(for: scheme).opacity(0.55))
                .frame(width: 1, height: height)
                .offset(x: x)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func todayFlag(_ plan: GanttPlan, width: CGFloat) -> some View {
        if let x = todayOffset(plan, width: width) {
            Text("Today")
                .font(type.caption)
                .foregroundStyle(Hue.moss.color(for: scheme))
                .offset(x: min(max(0, x + 3), max(0, width - 44)))
        }
    }

    private func todayOffset(_ plan: GanttPlan, width: CGFloat) -> CGFloat? {
        let now = Date()
        guard now >= plan.window.start, now <= plan.window.end else { return nil }
        return CGFloat(GanttMath.fraction(of: now, in: plan.window)) * width
    }

    private func dependencyLinks(_ plan: GanttPlan, width: CGFloat) -> some View {
        var centers: [String: CGFloat] = [:]
        var y = CGFloat.zero
        for row in plan.rows {
            centers[row.id] = y + rowHeight(row) / 2
            y += rowHeight(row)
        }
        return Path { path in
            for link in plan.links {
                guard let from = plan.rows.first(where: { $0.id == link.from }),
                      let to = plan.rows.first(where: { $0.id == link.to }),
                      let fromY = centers[link.from],
                      let toY = centers[link.to] else { continue }
                let fromX = CGFloat(GanttMath.fraction(of: from.marker ?? from.end, in: plan.window)) * width
                let toX = CGFloat(GanttMath.fraction(of: to.start, in: plan.window)) * width
                let elbow = toX > fromX + 2 * Metrics.ganttLinkElbow
                    ? toX - Metrics.ganttLinkElbow
                    : fromX + Metrics.ganttLinkElbow
                path.move(to: CGPoint(x: fromX, y: fromY))
                path.addLine(to: CGPoint(x: elbow, y: fromY))
                path.addLine(to: CGPoint(x: elbow, y: toY))
                path.addLine(to: CGPoint(x: toX, y: toY))
                path.move(to: CGPoint(x: toX - 4, y: toY - 3))
                path.addLine(to: CGPoint(x: toX, y: toY))
                path.addLine(to: CGPoint(x: toX - 4, y: toY + 3))
            }
        }
        .stroke(Hue.slate.color(for: scheme).opacity(0.6), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        .allowsHitTesting(false)
    }

    // MARK: - Rows

    @ViewBuilder
    private func rowLabel(_ row: GanttRow) -> some View {
        switch row.kind {
        case .project:
            Button {
                open(row)
            } label: {
                HStack(spacing: 6) {
                    if let id = row.projectId, let project = store.project(id: id) {
                        ProjectIcon(project: project, imageData: store.markImage(for: project), size: 16)
                    }
                    Text(row.title)
                        .font(type.bodyStrong)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if row.milestoneCount > 0 {
                        Text("\(row.milestoneCount)")
                            .font(type.caption)
                            .foregroundStyle(StudioColor.tertiary)
                    }
                }
                .padding(.trailing, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canOpen(row))
            .help(canOpen(row) ? "Open \(row.title)'s Timeline" : row.title)
            .contextMenu { ChiefOfStaffMenuButton(selectedText: FocusedSelection.currentText()) }
        case .milestone:
            HStack(spacing: 6) {
                Text(row.title)
                    .font(type.body)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(row.end, format: .dateTime.day().month(.abbreviated))
                    .font(type.caption)
                    .foregroundStyle(StudioColor.secondary)
            }
            .padding(.leading, 18)
            .padding(.trailing, 12)
            .help(milestoneHelp(row))
            .contextMenu { ChiefOfStaffMenuButton(selectedText: FocusedSelection.currentText()) }
        }
    }

    @ViewBuilder
    private func barTrack(_ row: GanttRow, plan: GanttPlan, width: CGFloat) -> some View {
        let startX = CGFloat(GanttMath.fraction(of: row.start, in: plan.window)) * width
        let endX = CGFloat(GanttMath.fraction(of: row.end, in: plan.window)) * width
        let barWidth = max(Metrics.ganttBarMin, endX - startX)
        ZStack(alignment: .leading) {
            switch row.kind {
            case .project:
                Button {
                    open(row)
                } label: {
                    Capsule()
                        .fill(barColor(row).opacity(0.30))
                        .overlay(Capsule().stroke(barColor(row).opacity(0.55), lineWidth: 1))
                        .frame(width: barWidth, height: Metrics.ganttProjectBar)
                        .offset(x: startX)
                        .frame(width: width, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canOpen(row))
                .help(canOpen(row) ? "Open \(row.title)'s Timeline" : row.title)
                ForEach(row.marks) { mark in
                    Circle()
                        .fill(Hue.moss.color(for: scheme).opacity(0.75))
                        .frame(width: 5, height: 5)
                        .offset(x: CGFloat(GanttMath.fraction(of: mark.date, in: plan.window)) * width - 2.5)
                        .help(shippedHelp(mark))
                }
            case .milestone:
                Capsule()
                    .fill(barColor(row).opacity(0.45))
                    .frame(width: barWidth, height: Metrics.ganttMilestoneBar)
                    .offset(x: startX)
                Rectangle()
                    .fill(barColor(row))
                    .frame(width: Metrics.ganttDiamond, height: Metrics.ganttDiamond)
                    .rotationEffect(.degrees(45))
                    .offset(x: endX - Metrics.ganttDiamond / 2)
                    .help(milestoneHelp(row))
            }
        }
        .frame(width: width, alignment: .leading)
    }

    // MARK: - Helpers

    private func rowHeight(_ row: GanttRow) -> CGFloat {
        row.kind == .project ? Metrics.ganttProjectRow : Metrics.ganttMilestoneRow
    }

    private func barColor(_ row: GanttRow) -> Color {
        if let status = row.status {
            return Hue.milestone(status).color(for: scheme)
        }
        if let hex = row.projectColor {
            return Color(hex: hex)
        }
        return Hue.slate.color(for: scheme)
    }

    private func canOpen(_ row: GanttRow) -> Bool {
        projectId == nil && row.projectId != nil
    }

    private func open(_ row: GanttRow) {
        guard canOpen(row), let id = row.projectId else { return }
        store.openProjectTimeline(id)
    }

    private func milestoneHelp(_ row: GanttRow) -> String {
        var parts: [String] = []
        if let status = row.status {
            parts.append(MilestoneVocabulary.label(status))
        }
        parts.append("due \(RelativeTime.dayHeader(row.end))")
        let predecessors = row.dependsOn.compactMap { id in
            store.milestones.first { $0.id == id }?.title
        }
        if !predecessors.isEmpty {
            parts.append("after \(predecessors.joined(separator: ", "))")
        }
        if !row.relatedIdentifiers.isEmpty {
            parts.append(row.relatedIdentifiers.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private func shippedHelp(_ mark: GanttMark) -> String {
        [mark.identifier, mark.title].compactMap { $0 }.joined(separator: " ")
    }
}

private struct GanttViewportKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Adapts the existing milestone / issue store into the chart's inputs. There is no second store.
enum TimelineBuilder {
    static func projects(_ projects: [Project]) -> [GanttProjectInput] {
        projects.map { GanttProjectInput(id: $0.id, key: $0.key, name: $0.name, color: $0.color) }
    }

    static func milestones(_ milestones: [Milestone]) -> [GanttMilestoneInput] {
        milestones.map {
            GanttMilestoneInput(
                id: $0.id,
                projectId: $0.projectId,
                title: $0.title,
                targetDate: $0.targetDate,
                status: $0.status,
                dependsOn: $0.dependencyIds,
                relatedIdentifiers: $0.relatedIdentifiers
            )
        }
    }

    static func completedIssues(_ issues: [Issue]) -> [GanttEventInput] {
        issues.compactMap { issue in
            guard issue.status == .done, issue.archivedAt == nil, let completed = issue.completedAt else { return nil }
            return GanttEventInput(
                id: issue.id,
                projectId: issue.projectId,
                identifier: issue.identifier,
                title: issue.title,
                date: completed
            )
        }
    }
}
