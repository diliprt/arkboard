import SwiftUI

struct IssueListView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDeleteId: String?

    var body: some View {
        if store.filteredIssues.isEmpty {
            EmptyIssuesView(
                hasActiveSearch: !store.filter.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || store.filter.status != nil
                    || store.filter.priority != nil,
                showingArchived: store.filter.showDeleted
            )
        } else {
            List(selection: Bindable(store).selectedIssueId) {
                ForEach(store.filteredIssues) { issue in
                    IssueRowView(issue: issue, showProject: store.isInbox)
                        .tag(Optional(issue.id))
                        .contextMenu {
                            if store.filter.showDeleted {
                                Button("Restore") {
                                    Task {
                                        do {
                                            try await store.restoreIssue(issue.id)
                                        } catch {
                                            store.lastError = error.localizedDescription
                                        }
                                    }
                                }
                            } else {
                                Button("Archive", role: .destructive) {
                                    pendingDeleteId = issue.id
                                }
                            }
                        }
                }
            }
            .listStyle(.inset)
            .accessibilityLabel(store.isInbox ? "Inbox issue list" : "Project issue list")
            .confirmationDialog(
                "Archive this issue?",
                isPresented: Binding(
                    get: { pendingDeleteId != nil },
                    set: { if !$0 { pendingDeleteId = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Archive", role: .destructive) {
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
                    Text("\(issue.identifier) — \(issue.title) will be archived. You can undo for ~10s or restore from Archived.")
                } else {
                    Text("The issue will be archived (soft-deleted). Undo is available briefly.")
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

            ActorStackLite(names: store.actors(for: issue))
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [issue.identifier, issue.title]
        if showProject, let project = store.project(for: issue) {
            parts.insert(project.key, at: 1)
        }
        return parts.joined(separator: ", ")
    }
}
