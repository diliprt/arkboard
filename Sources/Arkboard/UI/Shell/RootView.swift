import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showNewProject = false
    @State private var outlineWidth = Metrics.outlineIdeal
    @State private var outlineDragStart: CGFloat?

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            HStack(spacing: 0) {
                document
                    .frame(minWidth: Metrics.documentMin, maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                if store.contentsVisible {
                    outlineDivider
                    ContentsOutline()
                        .frame(width: outlineWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: store.contentsVisible)
        }
        .navigationTitle(windowTitle)
        .navigationSubtitle(store.workspace?.name ?? "Origin Ark")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    store.setContentsVisible(!store.contentsVisible)
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help(store.contentsVisible ? "Hide Contents" : "Show Contents")
            }
        }
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

    private var outlineDivider: some View {
        Rectangle()
            .fill(StudioColor.hairline)
            .frame(width: 1)
            .overlay {
                Color.clear
                    .frame(width: 8)
                    .contentShape(Rectangle())
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if outlineDragStart == nil {
                            outlineDragStart = outlineWidth
                        }
                        let next = (outlineDragStart ?? outlineWidth) - value.translation.width
                        outlineWidth = min(Metrics.outlineMax, max(Metrics.outlineMin, next))
                    }
                    .onEnded { _ in
                        outlineDragStart = nil
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    @ViewBuilder
    private var document: some View {
        if case let .project(id) = store.sidebarSelection, let project = store.project(id: id) {
            ProjectHomeView(project: project)
                .id(project.id)
        } else {
            EmptyStateView(
                section: .portfolio,
                title: EmptyCopy.noProjects.0,
                sentence: EmptyCopy.noProjects.1,
                actionTitle: "New Project",
                minHeight: Metrics.emptyPaneMin
            ) {
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
