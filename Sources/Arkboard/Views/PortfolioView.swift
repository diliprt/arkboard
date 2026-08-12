import SwiftUI

struct PortfolioView: View {
    @Environment(AppStore.self) private var store
    @State private var tab: PortfolioTab = .overview
    @State private var editingMilestone: Milestone?
    @State private var showingCreate = false

    enum PortfolioTab: String, CaseIterable, Identifiable {
        case overview, timeline, milestones
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .timeline: return "Timeline"
            case .milestones: return "Milestones"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("Portfolio section", selection: $tab) {
                ForEach(PortfolioTab.allCases) { t in
                    Text(t.title).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            switch tab {
            case .overview:
                overviewScroll
            case .timeline:
                PortfolioTimelineView(events: store.timelineEvents)
            case .milestones:
                MilestonesPane(
                    onCreate: { showingCreate = true },
                    onEdit: { editingMilestone = $0 }
                )
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingCreate) {
            MilestoneEditorSheet(milestone: nil)
        }
        .sheet(item: $editingMilestone) { ms in
            MilestoneEditorSheet(milestone: ms)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Portfolio")
                    .font(.title2.weight(.semibold))
                Text("Bird's-eye across projects — overview, shared timeline, milestones")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if tab == .milestones {
                Button {
                    showingCreate = true
                } label: {
                    Label("New milestone", systemImage: "plus")
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var overviewScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                totalsRow
                if store.portfolioCards.isEmpty {
                    ContentUnavailableView(
                        "No projects yet",
                        systemImage: "square.grid.2x2",
                        description: Text("Create a project to see portfolio cards.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                        ForEach(store.portfolioCards) { card in
                            ProjectPortfolioCardView(card: card) {
                                store.selectProject(card.project.id)
                            }
                        }
                    }
                }
                seedBar
            }
            .padding(20)
        }
    }

    private var totalsRow: some View {
        let t = store.portfolioTotals
        return HStack(spacing: 12) {
            PortfolioStatChip(title: "Open work", value: t.openWork, tint: Color(hex: "#5E6AD2"))
            PortfolioStatChip(title: "In progress", value: t.inProgress, tint: Color(hex: "#F2C94C"))
            PortfolioStatChip(title: "Features", value: t.features, tint: Color(hex: "#4EA7FC"))
            PortfolioStatChip(title: "Bugs", value: t.bugs, tint: Color(hex: "#EB5757"))
            Spacer(minLength: 0)
        }
    }

    private var seedBar: some View {
        HStack {
            Text("Need a demo of agents talking?")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Seed demo agent activity") {
                Task { await store.seedDemoAgentActivity() }
            }
            .controlSize(.small)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Milestones pane

private struct MilestonesPane: View {
    @Environment(AppStore.self) private var store
    let onCreate: () -> Void
    let onEdit: (Milestone) -> Void

    var body: some View {
        if store.milestones.isEmpty {
            ContentUnavailableView {
                Label("No milestones yet", systemImage: "flag")
            } description: {
                Text("Track studio-wide and per-project targets on a shared calendar.")
            } actions: {
                Button("New milestone", action: onCreate)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(store.milestonesGrouped, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                if let project = group.project {
                                    Circle()
                                        .fill(Color(hex: project.color))
                                        .frame(width: 8, height: 8)
                                } else {
                                    Image(systemName: "building.2")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(group.title)
                                    .font(.headline)
                                Spacer()
                                Text("\(group.items.count)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(group.items) { ms in
                                MilestoneCard(milestone: ms, project: group.project) {
                                    onEdit(ms)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}

private struct MilestoneCard: View {
    let milestone: Milestone
    let project: Project?
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(milestone.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        StatusChip(text: milestone.status.displayName, hex: milestone.status.tintHex)
                    }
                    if !milestone.description.isEmpty {
                        Text(milestone.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 10) {
                        Label(milestone.targetDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        if let key = project?.key {
                            Text(key)
                                .font(.caption.monospaced())
                        } else {
                            Text("Studio")
                                .font(.caption.monospaced())
                        }
                        if !milestone.relatedIdentifiers.isEmpty {
                            Text(milestone.relatedIdentifiers.prefix(3).joined(separator: ", "))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatusChip: View {
    let text: String
    let hex: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(Color(hex: hex))
            .background(Color(hex: hex).opacity(0.16))
            .clipShape(Capsule())
    }
}

// MARK: - Timeline

struct PortfolioTimelineView: View {
    @Environment(AppStore.self) private var store
    let events: [TimelineEvent]

    private var weeks: [TimelineWeekBucket] {
        TimelineWeekBucket.bucket(events: events)
    }

    var body: some View {
        if events.isEmpty {
            ContentUnavailableView(
                "Timeline is empty",
                systemImage: "calendar",
                description: Text("Milestones and issue create/done events show up here.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    legend
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    ForEach(weeks) { week in
                        TimelineWeekSection(week: week)
                    }
                }
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(color: Color(hex: "#5E6AD2"), label: "Milestone")
            legendDot(color: Color.secondary.opacity(0.55), label: "Created")
            legendDot(color: Color(hex: "#27AE60"), label: "Done")
            Spacer()
            ForEach(store.projects) { p in
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: p.color)).frame(width: 7, height: 7)
                    Text(p.key).font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct TimelineWeekBucket: Identifiable {
    var id: String
    var start: Date
    var label: String
    var events: [TimelineEvent]

    static func bucket(events: [TimelineEvent]) -> [TimelineWeekBucket] {
        let cal = Calendar.current
        var map: [Date: [TimelineEvent]] = [:]
        for e in events {
            let day = cal.startOfDay(for: e.date)
            let weekday = cal.component(.weekday, from: day)
            // Start week on Monday-ish: shift so weekOfYear grouping is stable
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)) ?? day
            _ = weekday
            map[weekStart, default: []].append(e)
        }
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return map.keys.sorted().map { start in
            let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
            let label = formatter.string(from: start, to: end)
            let items = (map[start] ?? []).sorted { $0.date < $1.date }
            return TimelineWeekBucket(id: "\(start.timeIntervalSince1970)", start: start, label: label, events: items)
        }
    }
}

private struct TimelineWeekSection: View {
    let week: TimelineWeekBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(week.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            ForEach(week.events) { event in
                TimelineEventRow(event: event)
            }
        }
    }
}

private struct TimelineEventRow: View {
    let event: TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Axis
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            .padding(.leading, 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(event.date.formatted(date: .abbreviated, time: event.kind == .milestone ? .omitted : .shortened))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                    kindBadge
                    if let key = event.projectKey {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: event.projectColor)).frame(width: 6, height: 6)
                            Text(key).font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                    } else if event.kind == .milestone {
                        Text("Studio")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let status = event.statusLabel {
                        StatusChip(text: status, hex: statusTint)
                    }
                }
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(event.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.leading, 10)
            .padding(.trailing, 20)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dotColor: Color {
        switch event.kind {
        case .milestone: return Color(hex: event.projectColor)
        case .issueCreated: return Color.secondary.opacity(0.55)
        case .issueDone: return Color(hex: "#27AE60")
        }
    }

    private var kindBadge: some View {
        Text(kindLabel)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(dotColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private var kindLabel: String {
        switch event.kind {
        case .milestone: return "milestone"
        case .issueCreated: return "created"
        case .issueDone: return "done"
        }
    }

    private var statusTint: String {
        switch event.statusLabel?.lowercased() {
        case "planned": return "#4EA7FC"
        case "in progress": return "#F2C94C"
        case "done": return "#27AE60"
        case "missed": return "#EB5757"
        default: return event.projectColor
        }
    }
}

// MARK: - Editor sheet

struct MilestoneEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let milestone: Milestone?

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var targetDate: Date = Date()
    @State private var status: MilestoneStatus = .planned
    @State private var scopeKey: String = "studio"
    @State private var relatedRaw: String = ""
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(milestone == nil ? "New milestone" : "Edit milestone")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { Task { await save() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            Divider()
            Form {
                TextField("Title", text: $title)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                Picker("Status", selection: $status) {
                    ForEach(MilestoneStatus.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                Picker("Scope", selection: $scopeKey) {
                    Text("Studio-wide").tag("studio")
                    ForEach(store.projects) { p in
                        Text("\(p.key) — \(p.name)").tag(p.key)
                    }
                }
                TextField("Related issues (comma-separated)", text: $relatedRaw)
                if let errorText {
                    Text(errorText).foregroundStyle(.red).font(.caption)
                }
            }
            .formStyle(.grouped)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 440, minHeight: 420)
        .onAppear(perform: populate)
    }

    private func populate() {
        guard let milestone else {
            scopeKey = "studio"
            targetDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            return
        }
        title = milestone.title
        description = milestone.description
        targetDate = milestone.targetDate
        status = milestone.status
        if let p = store.project(forMilestone: milestone) {
            scopeKey = p.key
        } else {
            scopeKey = "studio"
        }
        relatedRaw = milestone.relatedIdentifiers.joined(separator: ", ")
    }

    private func save() async {
        let related = relatedRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        do {
            if let milestone {
                let newProjectId: String?? = {
                    if scopeKey == "studio" { return .some(nil) }
                    if let p = store.projects.first(where: { $0.key == scopeKey }) {
                        return .some(p.id)
                    }
                    return nil
                }()
                _ = try await store.updateMilestone(
                    id: milestone.id,
                    title: title,
                    description: description,
                    targetDate: targetDate,
                    status: status,
                    projectId: newProjectId,
                    relatedIssueIdentifiers: related,
                    actor: "Riyu"
                )
            } else {
                _ = try await store.createMilestone(
                    title: title,
                    description: description,
                    targetDate: targetDate,
                    status: status,
                    projectKey: scopeKey == "studio" ? nil : scopeKey,
                    relatedIssueIdentifiers: related,
                    actor: "Riyu"
                )
            }
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Overview cards

private struct PortfolioStatChip: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ProjectPortfolioCardView: View {
    let card: ProjectPortfolioCard
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: card.project.color))
                        .frame(width: 10, height: 10)
                    Text(card.project.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(card.project.key)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Text("\(card.total) issue\(card.total == 1 ? "" : "s") · \(card.openCount) open")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(IssueStatus.allCases) { status in
                        let count = card.byStatus[status] ?? 0
                        if count > 0 {
                            Text("\(status.displayName) \(count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: 10) {
                    Label("\(card.featureCount) feature", systemImage: "sparkles")
                    Label("\(card.bugCount) bug", systemImage: "ant")
                    Label("\(card.otherCount) other", systemImage: "tag")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
        .help("Open \(card.project.name)")
    }
}
