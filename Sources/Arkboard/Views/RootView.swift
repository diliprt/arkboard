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
                    switch store.viewMode {
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
            .disabled(store.projects.isEmpty)

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
        return n == 1 ? "1 issue" : "\(n) issues"
    }
}
