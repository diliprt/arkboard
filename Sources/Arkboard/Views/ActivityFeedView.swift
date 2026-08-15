import SwiftUI

struct ActivityFeedView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Activity")
                        .font(.title2.weight(.semibold))
                    Spacer(minLength: 8)
                    if !store.hasRichBotDialogue {
                        Button("Seed demo agent activity") {
                            Task { await store.seedDemoAgentActivity() }
                        }
                        .controlSize(.small)
                    }
                }

                Picker("Activity filter", selection: Bindable(store).activityFilter) {
                    ForEach(AppStore.ActivityFeedFilter.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Activity filter")

                Text("Agents talking — Product, Ops, Comms, and you")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            let items = store.filteredActivities
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No activity yet", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text(emptyDescription)
                } actions: {
                    if !store.hasRichBotDialogue {
                        Button("Seed demo agent activity") {
                            Task { await store.seedDemoAgentActivity() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let rows = Self.displayRows(items, collapseSystem: store.activityFilter == .all)
                List {
                    ForEach(rows) { row in
                        switch row {
                        case .single(let activity):
                            ActivityRow(activity: activity)
                                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                .contentShape(Rectangle())
                                .onTapGesture { open(activity) }
                        case .systemGroup(let group):
                            DisclosureGroup {
                                ForEach(group) { activity in
                                    ActivityRow(activity: activity)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                        .contentShape(Rectangle())
                                        .onTapGesture { open(activity) }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gearshape.2")
                                        .foregroundStyle(.secondary)
                                    Text("\(group.count) system updates")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func open(_ activity: Activity) {
        if let requirement = store.requirement(forActivity: activity) {
            store.selection = .monitor
            store.selectMonitorRequirement(requirement)
            store.expandedRequirementId = requirement.id
        } else if let issue = store.issue(forActivity: activity) {
            store.selection = .project(issue.projectId)
            store.selectedIssueId = issue.id
        } else if let project = store.project(forActivity: activity) {
            store.selectProject(project.id)
        }
    }

    private enum DisplayRow: Identifiable {
        case single(Activity)
        case systemGroup([Activity])

        var id: String {
            switch self {
            case .single(let a): return a.id
            case .systemGroup(let g): return "sys-" + g.map(\.id).joined(separator: ",")
            }
        }
    }

    /// Collapse *all* system activities into one disclosure when viewing All
    /// (not only consecutive runs — bots stay interleaved in feed order).
    private static func displayRows(_ items: [Activity], collapseSystem: Bool) -> [DisplayRow] {
        guard collapseSystem else { return items.map { .single($0) } }
        let system = items.filter { ActivityKind(rawValue: $0.kind) == .system }
        guard !system.isEmpty else { return items.map { .single($0) } }

        var rows: [DisplayRow] = []
        var insertedSystem = false
        for item in items {
            if ActivityKind(rawValue: item.kind) == .system {
                if !insertedSystem {
                    if system.count == 1 {
                        rows.append(.single(system[0]))
                    } else {
                        rows.append(.systemGroup(system))
                    }
                    insertedSystem = true
                }
            } else {
                rows.append(.single(item))
            }
        }
        return rows
    }

    private var emptyDescription: String {
        switch store.activityFilter {
        case .all:
            return "Mutations from the UI or MCP show up here. Seed a demo conversation to preview agents talking."
        case .bots:
            return "No bot activity in this filter. Seed the demo or widen to All."
        case .mentions:
            return "No @mentions or handoffs yet. Comments with @Ops / @Product / @Comms appear here."
        }
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ActivityRow: View {
    @Environment(AppStore.self) private var store
    let activity: Activity

    private var isSpeech: Bool {
        let kind = ActivityKind(rawValue: activity.kind)
        return kind == .comment || kind == .mention || kind == .handoff
            || activity.action == ActivityAction.commented.rawValue
    }

    private var targets: [String] { activity.targetActors }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatarCluster
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(actorLabel)
                        .font(.subheadline.weight(.semibold))
                    Text(actionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(activity.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Group {
                    if isSpeech {
                        Text(activity.summary)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(ActorStyle.color(for: activity.actor).opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Text(activity.summary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    if let requirement = store.requirement(forActivity: activity) {
                        Text(requirement.identifier)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    } else if let issue = store.issue(forActivity: activity) {
                        Text(issue.identifier)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if let project = store.project(forActivity: activity) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: project.color)).frame(width: 6, height: 6)
                            Text(project.key)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    kindChip
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(ActivityKind(rawValue: activity.kind) == .system ? 0.72 : 1)
    }

    @ViewBuilder
    private var avatarCluster: some View {
        if targets.isEmpty {
            ActorAvatar(name: activity.actor, size: 32)
                .frame(width: 88, alignment: .leading)
        } else {
            HStack(spacing: -4) {
                ActorAvatar(name: activity.actor, size: 28)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
                ForEach(Array(targets.prefix(3).enumerated()), id: \.offset) { _, name in
                    ActorAvatar(name: name, size: 28)
                }
                if targets.count > 3 {
                    Text("+\(targets.count - 3)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .frame(width: 88 + CGFloat(min(targets.count, 3) - 1) * 18, alignment: .leading)
        }
    }

    private var actorLabel: String {
        if targets.isEmpty { return activity.actor }
        return "\(activity.actor) → \(targets.joined(separator: ", "))"
    }

    private var actionLabel: String {
        if let kind = ActivityKind(rawValue: activity.kind), kind != .system {
            return kind.displayName
        }
        return ActivityAction(rawValue: activity.action)?.displayName
            ?? activity.action.replacingOccurrences(of: "_", with: " ")
    }

    @ViewBuilder
    private var kindChip: some View {
        if let kind = ActivityKind(rawValue: activity.kind), kind == .mention || kind == .handoff || kind == .comment {
            Text(kind.displayName)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ActorStyle.color(for: activity.actor).opacity(0.18))
                .clipShape(Capsule())
        } else if activity.action == ActivityAction.commented.rawValue {
            Text("comment")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ActorStyle.color(for: activity.actor).opacity(0.18))
                .clipShape(Capsule())
        }
    }
}
