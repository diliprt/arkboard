import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var showQuickAdd = false
    @State private var showNewProject = false

    var body: some View {
        Group {
            if store.isPortfolio || store.isActivity || store.isMonitor {
                // Full-width main pane — no empty detail column
                NavigationSplitView {
                    SidebarView(showNewProject: $showNewProject)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
                } detail: {
                    ContentColumn(showQuickAdd: $showQuickAdd, showNewProject: $showNewProject)
                }
            } else {
                NavigationSplitView {
                    SidebarView(showNewProject: $showNewProject)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
                } content: {
                    ContentColumn(showQuickAdd: $showQuickAdd, showNewProject: $showNewProject)
                        .navigationSplitViewColumnWidth(min: 340, ideal: 460, max: 740)
                } detail: {
                    issueDetailColumn
                }
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
        .onReceive(NotificationCenter.default.publisher(for: .arkboardComposer)) { _ in
            store.focusComposer()
        }
        .preferredColorScheme(store.appearance.colorScheme)
        .alert("Error", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
        .overlay(alignment: .bottom) {
            if let banner = store.undoDelete {
                HStack(spacing: 12) {
                    Text("Archived \(banner.identifier) · Undo available for ~10s")
                        .font(.subheadline.weight(.medium))
                    Spacer(minLength: 8)
                    Button("Undo") {
                        Task { await store.undoLastDelete() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Button {
                        store.clearUndoDelete()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.undoDelete?.issueId)
    }

    @ViewBuilder
    private var issueDetailColumn: some View {
        if store.projects.isEmpty {
            EmptyProjectsView()
        } else if let issue = store.selectedIssue {
            IssueDetailView(issue: issue)
                .id(issue.id)
        } else {
            SelectIssuePlaceholder()
        }
    }
}

struct ContentColumn: View {
    @Environment(AppStore.self) private var store
    @Binding var showQuickAdd: Bool
    @Binding var showNewProject: Bool

    var body: some View {
        Group {
            if store.isMonitor {
                MonitorView()
            } else if store.isPortfolio {
                PortfolioView()
            } else if store.isActivity {
                ActivityFeedView()
            } else {
                issueBrowser
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: store.selection) { _, newValue in
            // Leaving a project board should not keep board mode active in Inbox.
            if case .inbox = newValue, store.viewMode == .board {
                store.viewMode = .list
            }
            if case .monitor = newValue { store.viewMode = .list }
            if case .portfolio = newValue { store.viewMode = .list }
            if case .activity = newValue { store.viewMode = .list }
        }
    }

    private var issueBrowser: some View {
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
    }

    /// Board only when a single project is selected and not viewing Archived.
    private var effectiveViewMode: AppStore.ViewMode {
        if store.filter.showDeleted { return .list }
        return store.boardAvailable ? store.viewMode : .list
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
            // Inbox / Archived: hide Board segment (list-only).
            if store.boardAvailable && !store.filter.showDeleted {
                Picker("View", selection: Bindable(store).viewMode) {
                    ForEach(AppStore.ViewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .help("Switch between list and board")
                .accessibilityHint("List or board layout")
            }

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
                .buttonStyle(.borderedProminent)
                .help("Create an issue (agents usually do this via MCP)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                            .frame(minWidth: 22, minHeight: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }

                Toggle("Canceled", isOn: Bindable(store).filter.showCanceled)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .disabled(store.projects.isEmpty || store.filter.showDeleted)
                Toggle("Archived", isOn: Bindable(store).filter.showDeleted)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .disabled(store.projects.isEmpty)
                    .help("Show soft-deleted issues")
                    .onChange(of: store.filter.showDeleted) { _, show in
                        if show { store.viewMode = .list }
                    }

                if store.filter.hasActiveFilters {
                    Button("Clear filters") {
                        store.filter.clearActiveFilters()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .help("Reset search and archive filters")
                    .accessibilityLabel("Clear filters")
                }
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var subtitle: String {
        if store.projects.isEmpty { return "Create a project to get started" }
        let n = store.filteredIssues.count
        let count = n == 1 ? "1 issue" : "\(n) issues"
        if store.filter.showDeleted {
            return "\(count) · archived"
        }
        if store.isInbox {
            return "\(count) · list across projects"
        }
        return count
    }
}
