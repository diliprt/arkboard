import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Form {
            Section("Local MCP / API") {
                LabeledContent("Status") {
                    Text(store.mcpRunning ? "Running" : "Stopped")
                        .foregroundStyle(store.mcpRunning ? .green : .orange)
                }
                LabeledContent("MCP URL") {
                    Text("http://127.0.0.1:\(store.mcpPort)/mcp")
                        .textSelection(.enabled)
                        .font(AppTypography.mono(size: store.fontSize))
                }
                LabeledContent("REST API") {
                    Text("http://127.0.0.1:\(store.mcpPort)/api")
                        .textSelection(.enabled)
                        .font(AppTypography.mono(size: store.fontSize))
                }
                Button(store.mcpRunning ? "Restart MCP Server" : "Start MCP Server") {
                    store.stopMCP()
                    store.startMCP()
                }
            }

            Section("Database") {
                LabeledContent("Path") {
                    Text(AppDatabase.databasePath)
                        .textSelection(.enabled)
                        .font(.caption.monospaced())
                        .lineLimit(3)
                }
            }

            Section("Appearance") {
                Picker("Appearance", selection: Bindable(store).appearance) {
                    ForEach(AppearancePreference.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .onChange(of: store.appearance) { _, newValue in
                    newValue.persist()
                }

                Picker("Font size", selection: Bindable(store).fontSize) {
                    ForEach(AppFontSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .onChange(of: store.fontSize) { _, newValue in
                    newValue.persist()
                }

                Picker("Font", selection: Bindable(store).fontFamily) {
                    ForEach(AppFontFamily.allCases) { family in
                        Text(family.title).tag(family)
                    }
                }
                .onChange(of: store.fontFamily) { _, newValue in
                    newValue.persist()
                }
            }

            Section("About") {
                LabeledContent("App", value: "Arkboard v1")
                LabeledContent("Workspace", value: store.workspace?.name ?? "—")
                Link("GitHub Repository", destination: URL(string: "https://github.com/diliprt/arkboard")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
        .padding()
    }
}
