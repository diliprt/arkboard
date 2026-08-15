import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var showNewProject = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            detail
        } detail: {
            ContentsOutline()
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
        if case let .project(id) = store.sidebarSelection, let project = store.project(id: id) {
            ProjectHomeView(project: project)
                .id(project.id)
        } else {
            EmptyStateView(section: .portfolio, title: EmptyCopy.noProjects.0, sentence: EmptyCopy.noProjects.1, actionTitle: "New Project") {
                showNewProject = true
            }
        }
    }

    private var windowTitle: String {
        if case let .project(id) = store.sidebarSelection {
            return store.project(id: id)?.name ?? "Project"
        }
        return store.workspace?.name ?? "Arkboard"
    }
}

extension Notification.Name {
    static let arkboardNewProject = Notification.Name("arkboardNewProject")
    static let arkboardOpenSettings = Notification.Name("arkboardOpenSettings")
    static let arkboardFocusComposer = Notification.Name("arkboardFocusComposer")
}
