import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var showQuickAdd = false
    @State private var showNewProject = false

    var body: some View {
        NavigationSplitView {
            SidebarView(showNewProject: $showNewProject)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            ContentColumn(showQuickAdd: $showQuickAdd, showNewProject: $showNewProject)
                .navigationSplitViewColumnWidth(min: 340, ideal: 460, max: 740)
        } detail: {
            if store.projects.isEmpty {
                EmptyProjectsView()
            } else if let issue = store.selectedIssue {
                IssueDetailView(issue: issue)
                    .id(issue.id)
            } else {
                SelectIssuePlaceholder()
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet()
                .environment(store)
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet()
                .environment(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .arkboardQuickAdd)) { _ in
            if store.projects.isEmpty {
                showNewProject = true
            } else {
                showQuickAdd = true
            }
        }
        .alert("Error", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

struct ContentColumn: View {
    @Environment(AppStore.self) private var store
    @Binding var showQuickAdd: Bool
    @Binding var showNewProject: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            filterBar
            Divider()

            Group {
                if store.projects.isEmpty {
                    EmptyProjectsView()
                } else {
                    switch effectiveViewMode {
                    case .list:
                        IssueListView()
                    case .board:
                        BoardView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: store.selectedProjectId) { _, newValue in
            // Inbox is list-first; leaving a project board should not keep board mode active.
            if newValue == nil, store.viewMode == .board {
                store.viewMode = .list
            }
        }
    }

    /// Board only when a single project is selected.
    private var effectiveViewMode: AppStore.ViewMode {
        store.boardAvailable ? store.viewMode : .list
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.selectedProject?.name ?? "Inbox")
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Picker("View", selection: Bindable(store).viewMode) {
                ForEach(AppStore.ViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .disabled(store.projects.isEmpty || !store.boardAvailable)
            .help(store.boardAvailable
                  ? "Switch between list and board"
                  : "Select a project to use the board. Inbox stays list-first.")
            .accessibilityHint(store.boardAvailable
                               ? "List or board layout"
                               : "Board disabled in Inbox; select a project first")

            if store.projects.isEmpty {
                Button {
                    showNewProject = true
                } label: {
                    Label("New Project", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    showQuickAdd = true
                } label: {
                    Label("New Issue", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search issues", text: Bindable(store).filter.query)
                .textFieldStyle(.plain)
                .disabled(store.projects.isEmpty)
            if !store.filter.query.isEmpty {
                Button {
                    store.filter.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
            Toggle("Canceled", isOn: Bindable(store).filter.showCanceled)
                .toggleStyle(.checkbox)
                .font(.caption)
                .disabled(store.projects.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var subtitle: String {
        if store.projects.isEmpty { return "Create a project to get started" }
        let n = store.filteredIssues.count
        let count = n == 1 ? "1 issue" : "\(n) issues"
        if store.isInbox {
            return "\(count) · list across projects"
        }
        return count
    }
}
