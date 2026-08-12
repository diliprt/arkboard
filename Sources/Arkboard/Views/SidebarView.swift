import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Binding var showNewProject: Bool

    var body: some View {
        List(selection: Bindable(store).selection) {
            Section("Workspace") {
                Label(store.workspace?.name ?? "Origin Ark", systemImage: "building.2")
                    .foregroundStyle(.secondary)
            }

            Section("Views") {
                Label("Portfolio", systemImage: "square.grid.2x2")
                    .tag(SidebarSelection.portfolio)
                Label("Inbox", systemImage: "tray")
                    .tag(SidebarSelection.inbox)
                Label("Activity", systemImage: "bubble.left.and.bubble.right")
                    .tag(SidebarSelection.activity)
            }

            Section("Projects") {
                if store.projects.isEmpty {
                    Text("No projects yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.projects) { project in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: project.color))
                                .frame(width: 8, height: 8)
                            Text(project.name)
                                .lineLimit(1)
                            Spacer()
                            Text(project.key)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .tag(SidebarSelection.project(project.id))
                    }
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
            VStack(alignment: .leading, spacing: 8) {
                if store.projects.isEmpty {
                    Button {
                        showNewProject = true
                    } label: {
                        Label("New Project", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                HStack(spacing: 8) {
                    Circle()
                        .fill(store.mcpRunning ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(store.mcpRunning ? "MCP :\(store.mcpPort)" : "MCP offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(12)
            .background(.bar)
        }
    }
}
