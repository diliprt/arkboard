import SwiftUI

struct BoardView: View {
    @Environment(AppStore.self) private var store

    private var columns: [IssueStatus] {
        var cols = IssueStatus.allCases
        if !store.filter.showCanceled {
            cols = cols.filter { $0 != .canceled }
        }
        return cols
    }

    var body: some View {
        Group {
            if store.projects.isEmpty {
                EmptyProjectsView()
            } else if store.filteredIssues.isEmpty {
                EmptyIssuesView(
                    hasActiveSearch: !store.filter.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(columns) { status in
                            BoardColumnView(status: status, issues: store.issues(for: status))
                        }
                    }
                    .padding(16)
                    .frame(minHeight: 420)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }
}

struct BoardColumnView: View {
    @Environment(AppStore.self) private var store
    let status: IssueStatus
    let issues: [Issue]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(status.displayName)
                    .font(.headline)
                Spacer()
                Text("\(issues.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if issues.isEmpty {
                        Text("Drop issues here")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                    .foregroundStyle(Color.secondary.opacity(0.35))
                            )
                    }

                    ForEach(issues) { issue in
                        BoardCardView(issue: issue)
                            .onTapGesture {
                                store.selectedIssueId = issue.id
                            }
                            .draggable(issue.id) {
                                BoardCardView(issue: issue)
                                    .frame(width: 240)
                                    .opacity(0.9)
                            }
                            // Drop onto a card → insert before that card (within-column reorder + cross-column)
                            .dropDestination(for: String.self) { items, _ in
                                guard let id = items.first, id != issue.id else { return false }
                                Task {
                                    try? await store.moveIssue(id, to: status, before: issue.id)
                                    store.selectedIssueId = id
                                }
                                return true
                            }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(10)
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        // Drop onto column chrome / empty area → append at end
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            Task {
                try? await store.moveIssue(id, to: status, before: nil)
                store.selectedIssueId = id
            }
            return true
        }
    }
}

struct BoardCardView: View {
    @Environment(AppStore.self) private var store
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(issue.identifier)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: issue.priority.symbolName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(issue.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            if !store.labels(for: issue).isEmpty {
                HStack(spacing: 4) {
                    ForEach(store.labels(for: issue).prefix(3)) { label in
                        Text(label.name)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(hex: label.color).opacity(0.18))
                            .foregroundStyle(Color(hex: label.color))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(store.selectedIssueId == issue.id ? Color.accentColor : Color.secondary.opacity(0.12), lineWidth: store.selectedIssueId == issue.id ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}
