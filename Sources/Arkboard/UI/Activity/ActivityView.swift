import SwiftUI

struct ActivityView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    @State private var filter = 0

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                section: .activity,
                subtitle: "Everyone talking — agents and you.",
                trailing: AnyView(
                    Picker("Filter", selection: $filter) {
                        Text("People & agents").tag(0)
                        Text("Mentions").tag(1)
                        Text("All").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 360)
                )
            )
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                    if visible.isEmpty {
                        EmptyStateView(section: .activity, title: EmptyCopy.noActivity.0, sentence: EmptyCopy.noActivity.1)
                    } else {
                        ForEach(days, id: \.self) { day in
                            Section {
                                dayRows(day)
                            } header: {
                                Text(RelativeTime.dayHeader(day))
                                    .font(type.caption)
                                    .foregroundStyle(StudioColor.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                    .background(StudioColor.wash(.ember, scheme: scheme))
                            }
                        }
                    }
                }
                .padding(Metrics.paneX)
                .frame(maxWidth: Metrics.gridMax, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(StudioColor.wash(.ember, scheme: scheme))
        }
    }

    private var visible: [Activity] {
        store.activities.filter { row in
            switch filter {
            case 1: return !row.targets.isEmpty || row.kind == .mention || row.kind == .handoff
            case 2: return true
            default: return row.kind != .system
            }
        }
    }

    private var days: [Date] {
        let calendar = Calendar.current
        var seen: [Date] = []
        for row in visible {
            let day = calendar.startOfDay(for: row.createdAt)
            if !seen.contains(day) { seen.append(day) }
        }
        return seen
    }

    @ViewBuilder
    private func dayRows(_ day: Date) -> some View {
        let calendar = Calendar.current
        let rows = visible.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
        ForEach(renderItems(rows)) { item in
            switch item.kind {
            case .single:
                if let row = item.rows.first { rowView(row) }
            case .cluster:
                DisclosureGroup("\(item.rows.count) updates") {
                    ForEach(item.rows) { row in
                        systemRow(row)
                    }
                }
                .font(type.callout)
            }
        }
    }

    private func renderItems(_ rows: [Activity]) -> [ActivityCluster] {
        if filter != 2 {
            return rows.map { ActivityCluster(kind: .single, rows: [$0]) }
        }
        var result: [ActivityCluster] = []
        var index = 0
        while index < rows.count {
            if rows[index].kind == .system {
                var cursor = index
                while cursor < rows.count, rows[cursor].kind == .system {
                    cursor += 1
                }
                let slice = Array(rows[index..<cursor])
                if slice.count >= 3 {
                    result.append(ActivityCluster(kind: .cluster, rows: slice))
                } else {
                    for row in slice {
                        result.append(ActivityCluster(kind: .single, rows: [row]))
                    }
                }
                index = cursor
            } else {
                result.append(ActivityCluster(kind: .single, rows: [rows[index]]))
                index += 1
            }
        }
        return result
    }

    @ViewBuilder
    private func rowView(_ row: Activity) -> some View {
        if row.kind == .system {
            systemRow(row)
        } else {
            messageRow(row)
        }
    }

    private func systemRow(_ row: Activity) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(StudioColor.tertiary)
            Text(row.body)
                .font(type.callout)
                .foregroundStyle(StudioColor.secondary)
            Text(RelativeTime.format(row.createdAt))
                .font(type.caption)
                .foregroundStyle(StudioColor.tertiary)
        }
        .onTapGesture { navigate(row) }
    }

    private func messageRow(_ row: Activity) -> some View {
        let hue = Hue.actorHue(for: row.actor)
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ActorChip(name: row.actor)
                    if !row.targets.isEmpty {
                        Text("\(row.actor) → \(row.targets.joined(separator: ", "))")
                            .font(type.caption)
                            .foregroundStyle(StudioColor.secondary)
                    }
                    if let issueId = row.issueId, let issue = store.issue(idOrIdentifier: issueId) {
                        Chip(text: issue.identifier, hue: .teal, mono: true)
                    }
                    Spacer()
                    Text(RelativeTime.format(row.createdAt))
                        .font(type.caption)
                        .foregroundStyle(StudioColor.secondary)
                }
                MarkdownView(markdown: row.body, hue: hue)
            }
            .padding(Metrics.cardPad)
            .background(hue.color(for: scheme).opacity(0.10), in: RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
        }
        .onTapGesture { navigate(row) }
    }

    private func navigate(_ row: Activity) {
        if let issueId = row.issueId {
            store.selectedIssueID = issueId
            store.sidebarSelection = .issues
        } else if let projectId = row.projectId {
            store.sidebarSelection = .project(projectId)
        }
    }
}

struct ActivityCluster: Identifiable {
    enum Kind { case single, cluster }
    var id: String { rows.map(\.id).joined(separator: "+") }
    var kind: Kind
    var rows: [Activity]
}
