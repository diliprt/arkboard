import SwiftUI

struct IssueListView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.filteredIssues.isEmpty {
            EmptyIssuesView(
                hasActiveSearch: !store.filter.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        } else {
            List(selection: Bindable(store).selectedIssueId) {
                ForEach(store.filteredIssues) { issue in
                    IssueRowView(issue: issue)
                        .tag(Optional(issue.id))
                        .contextMenu {
                            statusMenu(for: issue)
                            Divider()
                            Button("Delete", role: .destructive) {
                                Task { try? await store.deleteIssue(issue.id) }
                            }
                        }
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private func statusMenu(for issue: Issue) -> some View {
        Menu("Status") {
            ForEach(IssueStatus.allCases) { status in
                Button(status.displayName) {
                    Task { try? await store.updateIssue(id: issue.id, status: status) }
                }
            }
        }
        Menu("Priority") {
            ForEach(IssuePriority.allCases) { priority in
                Button(priority.displayName) {
                    Task { try? await store.updateIssue(id: issue.id, priority: priority) }
                }
            }
        }
    }
}

struct IssueRowView: View {
    @Environment(AppStore.self) private var store
    let issue: Issue

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
                .frame(width: 16)

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

            Image(systemName: issue.priority.symbolName)
                .font(.caption)
                .foregroundStyle(priorityColor)
                .frame(width: 16)

            Text(issue.status.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
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
