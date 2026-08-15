import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var showQuickAdd = false
    @State private var showNewProject = false

    var body: some View {
        Group {
            if store.isInbox {
                NavigationSplitView {
                    SidebarView(showNewProject: $showNewProject)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
                } content: {
                    IssuesTrackingView(showQuickAdd: $showQuickAdd, showNewProject: $showNewProject)
                        .navigationSplitViewColumnWidth(min: 340, ideal: 460, max: 740)
                } detail: {
                    issueDetailColumn
                }
            } else {
                NavigationSplitView {
                    SidebarView(showNewProject: $showNewProject)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
                } detail: {
                    mainPane
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
        .appTypography(size: store.fontSize, family: store.fontFamily)
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
    private var mainPane: some View {
        if store.isMonitor {
            MonitorView()
        } else if store.isPortfolio {
            PortfolioView()
        } else if store.isActivity {
            ActivityFeedView()
        } else if let project = store.selectedProject {
            ProjectHomeView(project: project)
                .id(project.id)
        } else if store.projects.isEmpty {
            EmptyProjectsView()
        } else {
            ContentUnavailableView("Select a project", systemImage: "folder")
        }
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

struct IssuesTrackingView: View {
    @Environment(AppStore.self) private var store
    @Binding var showQuickAdd: Bool
    @Binding var showNewProject: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Issues")
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
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
                    .help("Create an issue (⌘⇧N).")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search issues", text: Bindable(store).filter.query)
                    .textFieldStyle(.plain)
                    .appBodyFont()
                    .disabled(store.projects.isEmpty)
                if !store.filter.query.isEmpty {
                    Button {
                        store.filter.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Toggle("Archived", isOn: Bindable(store).filter.showDeleted)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .disabled(store.projects.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            Group {
                if store.projects.isEmpty {
                    EmptyProjectsView()
                } else {
                    IssueListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sectionWash(.issues)
    }

    private var subtitle: String {
        if store.projects.isEmpty { return "Create a project to get started" }
        let n = store.filteredIssues.count
        let count = n == 1 ? "1 issue" : "\(n) issues"
        if store.filter.showDeleted { return "\(count) · archived" }
        return "\(count) · across projects"
    }
}
