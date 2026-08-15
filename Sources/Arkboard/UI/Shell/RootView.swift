import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var showNewProject = false

    var body: some View {
        Group {
            if store.sidebarSelection == .issues {
                NavigationSplitView {
                    SidebarView()
                } content: {
                    IssueListColumn()
                } detail: {
                    IssueDetailColumn()
                }
            } else {
                NavigationSplitView {
                    SidebarView()
                } detail: {
                    detail
                }
            }
        }
        .navigationTitle(windowTitle)
        .navigationSubtitle(store.workspace?.name ?? "Origin Ark")
        .overlay(alignment: .bottom) {
            if let undo = store.undoArchive {
                UndoToast(
                    identifier: undo.issue.identifier,
                    onUndo: { store.undoArchiveIfNeeded() },
                    onDismiss: { store.undoArchive = nil }
                )
                .padding(.bottom, 24)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        if store.undoArchive?.issue.id == undo.issue.id {
                            store.undoArchive = nil
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .arkboardNewProject)) { _ in
            showNewProject = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .arkboardOpenSettings)) { _ in
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch store.sidebarSelection {
        case .monitor:
            MonitorView()
        case .activity:
            ActivityView()
        case .portfolio:
            PortfolioView()
        case .project(let id):
            if let project = store.project(id: id) {
                ProjectHomeView(project: project)
            } else {
                EmptyStateView(section: .portfolio, title: EmptyCopy.noProjects.0, sentence: EmptyCopy.noProjects.1)
            }
        case .issues:
            IssueListColumn()
        }
    }

    private var windowTitle: String {
        switch store.sidebarSelection {
        case .monitor: return "Monitor"
        case .issues: return "Issues"
        case .activity: return "Activity"
        case .portfolio: return "Portfolio"
        case .project(let id): return store.project(id: id)?.name ?? "Project"
        }
    }
}

extension Notification.Name {
    static let arkboardNewProject = Notification.Name("arkboardNewProject")
    static let arkboardOpenSettings = Notification.Name("arkboardOpenSettings")
    static let arkboardFocusComposer = Notification.Name("arkboardFocusComposer")
}
