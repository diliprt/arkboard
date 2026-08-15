import SwiftUI

struct EmptyProjectsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNewProject = false

    var body: some View {
        ContentUnavailableView {
            Label("No projects yet", systemImage: "folder.badge.plus")
        } description: {
            Text("Create a project to get started.")
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
                Text("Try a different search or clear filters.")
            }
        } else {
            ContentUnavailableView {
                Label("No issues", systemImage: "tray")
            } description: {
                Text("Nothing filed yet. ⌘⇧N adds one.")
            }
        }
    }
}

struct SelectIssuePlaceholder: View {
    var body: some View {
        ContentUnavailableView {
            Label("Select an issue", systemImage: "checkmark.circle")
        } description: {
            Text("Choose an issue from the list. ⌘N tells the team from Monitor. ⌘⇧N adds an issue.")
        }
    }
}
