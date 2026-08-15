import SwiftUI

@main
struct ArkboardApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task {
                    await store.start()
                }
                .frame(minWidth: 1100, minHeight: 680)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Tell the team…") {
                    NotificationCenter.default.post(name: .arkboardComposer, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                Button("New Issue") {
                    NotificationCenter.default.post(name: .arkboardQuickAdd, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}

extension Notification.Name {
    static let arkboardQuickAdd = Notification.Name("arkboardQuickAdd")
    static let arkboardComposer = Notification.Name("arkboardComposer")
}
