import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Binding var showNewProject: Bool

    var body: some View {
        List(selection: Bindable(store).selectedProjectId) {
            Section("Workspace") {
                Label(store.workspace?.name ?? "Origin Ark", systemImage: "building.2")
                    .foregroundStyle(.secondary)
            }

            Section("Views") {
                Label("Inbox", systemImage: "tray")
                    .tag(Optional<String>.none)
            }

            Section("Projects") {
                ForEach(store.projects) { project in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: project.color))
                            .frame(width: 8, height: 8)
                        Text(project.name)
                        Spacer()
                        Text(project.key)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .tag(Optional(project.id))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Arkboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewProject = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("New Project")
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Circle()
                    .fill(store.mcpRunning ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(store.mcpRunning ? "MCP :\(store.mcpPort)" : "MCP offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .background(.bar)
        }
    }
}
