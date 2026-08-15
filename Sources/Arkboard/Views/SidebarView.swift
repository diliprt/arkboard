import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Binding var showNewProject: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "building.2")
                    .foregroundStyle(StudioSection.monitor.accent)
                Text(store.workspace?.name ?? "Origin Ark")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Workspace \(store.workspace?.name ?? "Origin Ark")")

            List(selection: Bindable(store).selection) {
                Section("Studio") {
                    Label {
                        Text("Monitor")
                    } icon: {
                        Image(systemName: StudioSection.monitor.symbol)
                            .foregroundStyle(StudioSection.monitor.accent)
                    }
                    .tag(SidebarSelection.monitor)

                    Label {
                        Text("Issues")
                    } icon: {
                        Image(systemName: StudioSection.issues.symbol)
                            .foregroundStyle(StudioSection.issues.accent)
                    }
                    .tag(SidebarSelection.inbox)

                    Label {
                        Text("Activity")
                    } icon: {
                        Image(systemName: StudioSection.activity.symbol)
                            .foregroundStyle(StudioSection.activity.accent)
                    }
                    .tag(SidebarSelection.activity)

                    Label {
                        Text("Portfolio")
                    } icon: {
                        Image(systemName: StudioSection.portfolio.symbol)
                            .foregroundStyle(StudioSection.portfolio.accent)
                    }
                    .tag(SidebarSelection.portfolio)
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
        }
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
