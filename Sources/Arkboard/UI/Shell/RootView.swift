import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showNewProject = false
    @State private var outlineDragStart: CGFloat?

    /// The overlay's width lives in the store because the document needs it too:
    /// it reserves exactly this much trailing gutter so prose is never clipped.
    private var outlineWidth: CGFloat { store.contentsWidth }

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            document
                .frame(minWidth: Metrics.documentMin, maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(alignment: .trailing) {
                    if showsContents {
                        HStack(spacing: 0) {
                            outlineDivider
                            ContentsOutline()
                                .frame(width: outlineWidth)
                        }
                        .transition(.move(edge: .trailing))
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: showsContents)
        }
        .navigationTitle(windowTitle)
        .navigationSubtitle(store.workspace?.name ?? "Origin Ark")
        // One title, on one row, on every screen. Left to `.automatic`, AppKit
        // gives the title its own line under the toolbar when a screen has few
        // toolbar items — which is why Timeline, with only the Contents toggle,
        // grew a second row that read as an in-page title band while Portfolio
        // and the project page kept theirs inline.
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: Binding(
                    get: { store.contentsVisible },
                    set: { store.setContentsVisible($0) }
                )) {
                    SwiftUI.Label("Contents", systemImage: "sidebar.trailing")
                }
                .toggleStyle(.button)
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
        .sheet(item: Binding(
            get: { store.noteSheet },
            set: { store.noteSheet = $0 }
        )) { request in
            ProjectNoteSheet(project: request.project, initialDraft: request.draft, handoff: request.handoff)
        }
        .chiefOfStaffContextMenu()
        .onAppear {
            store.publishPageFocus(PageFocus.from(selection: store.sidebarSelection, projects: store.projects))
            ChiefOfStaffMenuBridge.shared.install { selected in
                store.beginChiefHandoff(selectedText: selected)
            }
        }
        .onChange(of: store.sidebarSelection) { _, next in
            store.publishPageFocus(PageFocus.from(selection: next, projects: store.projects))
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
                        store.setContentsWidth((outlineDragStart ?? outlineWidth) - value.translation.width)
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
        switch store.sidebarSelection {
        case .timeline:
            TimelineView()
        case .onboarding:
            OnboardingView()
        case .project(let id):
            if let project = store.project(id: id) {
                ProjectHomeView(project: project)
                    .id(project.id)
            } else {
                PortfolioView()
            }
        case .portfolio, .none:
            PortfolioView()
        }
    }

    private var showsContents: Bool {
        guard store.contentsVisible else { return false }
        switch store.sidebarSelection {
        case .project, .onboarding:
            return true
        default:
            return false
        }
    }

    private var windowTitle: String {
        switch store.sidebarSelection {
        case .portfolio, .none:
            return "Portfolio"
        case .timeline:
            return "Timeline"
        case .onboarding:
            return "Onboarding"
        case .project(let id):
            return store.project(id: id)?.name ?? "Project"
        }
    }
}

extension Notification.Name {
    static let arkboardNewProject = Notification.Name("arkboardNewProject")
    static let arkboardOpenSettings = Notification.Name("arkboardOpenSettings")
    static let arkboardFocusComposer = Notification.Name("arkboardFocusComposer")
}
