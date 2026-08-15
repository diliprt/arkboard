import AppKit
import SwiftUI

@main
struct ArkboardApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .modifier(StudioRoot(
                    typography: Typography(bodySize: CGFloat(store.fontSize), family: store.fontFamily),
                    appearance: store.appearance
                ))
                .task { await store.start() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await store.becomeActive() }
                }
                .frame(minWidth: Metrics.windowMin.width, minHeight: Metrics.windowMin.height)
        }
        .windowStyle(.automatic)
        .defaultSize(width: Metrics.windowDefault.width, height: Metrics.windowDefault.height)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Tell the team…") {
                    store.goToComposer()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Studio") {
                Button("Find Issues") { store.goToProjectIssues() }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Reload Documents") {
                    if case let .project(id) = store.sidebarSelection {
                        Task { await store.refreshDocuments(projectId: id) }
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                Button("Previous Tab") {
                    NotificationCenter.default.post(name: .arkboardTabPrev, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)
                Button("Next Tab") {
                    NotificationCenter.default.post(name: .arkboardTabNext, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .modifier(StudioRoot(
                    typography: Typography(bodySize: CGFloat(store.fontSize), family: store.fontFamily),
                    appearance: store.appearance
                ))
        }
    }
}

extension Notification.Name {
    static let arkboardTabPrev = Notification.Name("arkboardTabPrev")
    static let arkboardTabNext = Notification.Name("arkboardTabNext")
}
