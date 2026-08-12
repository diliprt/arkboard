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

    var body: some View {
        if hasActiveSearch {
            ContentUnavailableView(
                "No matching issues",
                systemImage: "magnifyingglass",
                description: Text("Try a different search, clear the query, or create a new issue with ⌘N.")
            )
        } else {
            ContentUnavailableView {
                Label("No issues", systemImage: "tray")
            } description: {
                Text("Press ⌘N to create your first issue, or ask an agent to create one via MCP.")
            }
        }
    }
}

struct SelectIssuePlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Select an issue",
            systemImage: "checkmark.circle",
            description: Text("Choose an issue from the list or board, or press ⌘N to create one.")
        )
    }
}
