import SwiftUI

struct EmptyProjectsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNewProject = false

    var body: some View {
        ContentUnavailableView {
            Label("No projects yet", systemImage: "folder.badge.plus")
        } description: {
            Text("Create a project to start tracking issues. Agents can also create projects via the local MCP API.")
        } actions: {
            Button("New Project") {
                showNewProject = true
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet()
                .environment(store)
        }
    }
}

struct EmptyIssuesView: View {
    var hasActiveSearch: Bool = false
    var showingArchived: Bool = false

    var body: some View {
        if showingArchived {
            ContentUnavailableView {
                Label("No archived issues", systemImage: "trash")
            } description: {
                Text("Deleted issues land here for a bit. Restore one from the undo toast or this Archived filter.")
            }
        } else if hasActiveSearch {
            ContentUnavailableView {
                Label("No matching issues", systemImage: "magnifyingglass")
            } description: {
                Text("Try a different search, clear filters, or create a new issue.")
            } actions: {
                Button("New Issue") {
                    NotificationCenter.default.post(name: .arkboardQuickAdd, object: nil)
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView {
                Label("No issues", systemImage: "tray")
            } description: {
                Text("Create your first issue, or ask an agent to create one via MCP.")
            } actions: {
                Button("New Issue") {
                    NotificationCenter.default.post(name: .arkboardQuickAdd, object: nil)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

struct SelectIssuePlaceholder: View {
    var body: some View {
        ContentUnavailableView {
            Label("Select an issue", systemImage: "checkmark.circle")
        } description: {
            Text("Choose an issue from the list (or a project board), or press ⌘N to create one.")
        } actions: {
            Button("New Issue") {
                NotificationCenter.default.post(name: .arkboardQuickAdd, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}
