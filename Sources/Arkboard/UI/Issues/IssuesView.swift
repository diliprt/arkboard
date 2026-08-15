import AppKit
import SwiftUI

struct IssueListColumn: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    @State private var query = ""
    @State private var scope: String = "all"
    @State private var showArchived = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(section: .issues, subtitle: "Tracking. Agents file and update these.")
            VStack(alignment: .leading, spacing: 8) {
                TextField("Search issues", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                HStack {
                    Picker("Scope", selection: $scope) {
                        Text("All projects").tag("all")
                        ForEach(store.projects) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                    .labelsHidden()
                    Toggle("Archived", isOn: $showArchived)
                        .toggleStyle(.switch)
                        .font(type.caption)
                }
            }
            .padding(12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    group(.underway)
                    group(.queued)
                    group(.done)
                    if showArchived { group(.archived) }
                    if allEmpty {
                        EmptyStateView(
                            section: .issues,
                            title: emptyTitle.0,
                            sentence: emptyTitle.1
                        )
                    }
                }
                .padding(.bottom, 24)
            }
            .background(StudioColor.wash(.teal, scheme: scheme))
        }
        .navigationSplitViewColumnWidth(min: Metrics.issuesMin, ideal: Metrics.issuesIdeal, max: Metrics.issuesMax)
        .onChange(of: store.focusIssueSearch) { _, _ in searchFocused = true }
    }

    private var grouped: [HumanIssueGroup: [Issue]] {
        store.humanIssues(projectId: scope == "all" ? nil : scope, query: query, includeArchived: showArchived)
    }

    private var allEmpty: Bool {
        HumanIssueGroup.allCases.allSatisfy { grouped[$0, default: []].isEmpty }
    }

    private var emptyTitle: (String, String) {
        if !query.isEmpty { return EmptyCopy.noMatch }
        if showArchived { return EmptyCopy.nothingArchived }
        return EmptyCopy.noIssues
    }

    @ViewBuilder
    private func group(_ group: HumanIssueGroup) -> some View {
        let rows = grouped[group, default: []]
        if !rows.isEmpty {
            Section {
                ForEach(rows) { issue in
                    IssueRowView(issue: issue, showProject: scope == "all")
                        .contentShape(Rectangle())
                        .onTapGesture { store.selectedIssueID = issue.id }
                        .background(store.selectedIssueID == issue.id ? StudioColor.chipFill(.teal, scheme: scheme) : Color.clear)
                        .contextMenu {
                            Button("Copy identifier") { copy(issue.identifier) }
                            Button("Copy title") { copy(issue.title) }
                            Button("Archive") { store.archiveFromUI(issue) }
                        }
                }
            } header: {
                HStack {
                    Text(group.rawValue.uppercased())
                        .font(type.caption)
                        .foregroundStyle(Hue.teal.color(for: scheme))
                    Text("\(rows.count)")
                        .font(type.caption)
                        .foregroundStyle(StudioColor.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(StudioColor.window)
            }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct IssueRowView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.typography) private var type
    var issue: Issue
    var showProject: Bool

    var body: some View {
        HStack(spacing: 8) {
            if showProject, let project = store.project(id: issue.projectId) {
                ProjectIcon(project: project, imageData: store.markImage(for: project), size: 16)
                Text(project.key).font(type.mono).foregroundStyle(StudioColor.secondary)
            }
            Text(issue.identifier)
                .font(type.mono)
                .foregroundStyle(StudioColor.secondary)
            Text(issue.title)
                .font(type.body)
                .lineLimit(1)
            ForEach(store.labels(for: issue), id: \.self) { name in
                Chip(text: name, hue: .slate)
            }
            Spacer()
            Text(RelativeTime.format(issue.updatedAt))
                .font(type.caption)
                .foregroundStyle(StudioColor.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct StudioIssuesView: View {
    @Environment(\.typography) private var type
    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(section: .issues, subtitle: "Tracking. Agents file and update these.")
            IssueListColumn()
        }
    }
}
