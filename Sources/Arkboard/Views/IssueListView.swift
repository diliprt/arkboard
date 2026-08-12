import SwiftUI

struct IssueListView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDeleteId: String?

    var body: some View {
        if store.filteredIssues.isEmpty {
            EmptyIssuesView(
                hasActiveSearch: !store.filter.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || store.filter.status != nil
            )
        } else {
            List(selection: Bindable(store).selectedIssueId) {
                ForEach(store.filteredIssues) { issue in
                    IssueRowView(issue: issue, showProject: store.isInbox)
                        .tag(Optional(issue.id))
                        .contextMenu {
                            statusMenu(for: issue)
                            Divider()
                            Button("Delete", role: .destructive) {
                                pendingDeleteId = issue.id
                            }
                        }
                }
            }
            .listStyle(.inset)
            .accessibilityLabel(store.isInbox ? "Inbox issue list" : "Project issue list")
            .confirmationDialog(
                "Delete this issue?",
                isPresented: Binding(
                    get: { pendingDeleteId != nil },
                    set: { if !$0 { pendingDeleteId = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let id = pendingDeleteId else { return }
                    pendingDeleteId = nil
                    Task {
                        do {
                            try await store.deleteIssue(id)
                        } catch {
                            store.lastError = error.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) { pendingDeleteId = nil }
            } message: {
                if let id = pendingDeleteId, let issue = store.issues.first(where: { $0.id == id }) {
                    Text("\(issue.identifier) — \(issue.title) will be permanently removed.")
                } else {
                    Text("This cannot be undone.")
                }
            }
        }
    }

    @ViewBuilder
    private func statusMenu(for issue: Issue) -> some View {
        Menu("Status") {
            ForEach(IssueStatus.allCases) { status in
                Button(status.displayName) {
                    Task {
                        do {
                            try await store.updateIssue(id: issue.id, status: status)
                        } catch {
                            store.lastError = error.localizedDescription
                        }
                    }
                }
            }
        }
        Menu("Priority") {
            ForEach(IssuePriority.allCases) { priority in
                Button(priority.displayName) {
                    Task {
                        do {
                            try await store.updateIssue(id: issue.id, priority: priority)
                        } catch {
                            store.lastError = error.localizedDescription
                        }
                    }
                }
            }
        }
    }
}

struct IssueRowView: View {
    @Environment(AppStore.self) private var store
    let issue: Issue
    var showProject: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
                .frame(width: 16)
                .accessibilityHidden(true)

            Text(issue.identifier)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(minWidth: 56, idealWidth: 72, maxWidth: 88, alignment: .leading)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .lineLimit(1)
                if !store.labels(for: issue).isEmpty {
                    HStack(spacing: 6) {
                        ForEach(store.labels(for: issue).prefix(3)) { label in
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: label.color).opacity(0.2))
                                .foregroundStyle(Color(hex: label.color))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            if showProject, let project = store.project(for: issue) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: project.color))
                        .frame(width: 6, height: 6)
                    Text(project.key)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
                .accessibilityLabel("Project \(project.key)")
            }

            Image(systemName: issue.priority.symbolName)
                .font(.caption)
                .foregroundStyle(priorityColor)
                .frame(width: 16)
                .accessibilityLabel(issue.priority.displayName)

            Text(issue.status.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [issue.identifier, issue.title, issue.status.displayName, issue.priority.displayName]
        if showProject, let project = store.project(for: issue) {
            parts.insert(project.key, at: 1)
        }
        return parts.joined(separator: ", ")
    }

    private var statusSymbol: String {
        switch issue.status {
        case .backlog: return "circle.dotted"
        case .todo: return "circle"
        case .in_progress: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        case .canceled: return "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch issue.status {
        case .backlog: return .secondary
        case .todo: return .gray
        case .in_progress: return .yellow
        case .done: return .green
        case .canceled: return .secondary
        }
    }

    private var priorityColor: Color {
        switch issue.priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .none: return .secondary
        }
    }
}
