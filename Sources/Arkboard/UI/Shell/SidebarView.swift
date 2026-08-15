import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type

    var body: some View {
        @Bindable var store = store
        List(selection: $store.sidebarSelection) {
            Section {
                SwiftUI.Label {
                    Text(store.workspace?.name ?? "Origin Ark")
                        .font(type.bodyStrong)
                } icon: {
                    Image(systemName: "building.2")
                        .foregroundStyle(Hue.indigo.color(for: scheme))
                }
                .listRowSeparator(.hidden)
            }
            Section {
                ForEach(store.projects) { project in
                    NavigationLink(value: SidebarItem.project(project.id)) {
                        HStack(spacing: 8) {
                            ProjectIcon(
                                project: project,
                                imageData: store.markImage(for: project),
                                size: 22
                            )
                            Text(project.name)
                                .font(type.body)
                            Spacer()
                            Text(project.key)
                                .font(type.mono)
                                .foregroundStyle(StudioColor.secondary)
                        }
                    }
                    .tag(SidebarItem.project(project.id))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: Metrics.sidebarMin, ideal: Metrics.sidebarIdeal, max: Metrics.sidebarMax)
        .safeAreaInset(edge: .bottom) {
            Button {
                NotificationCenter.default.post(name: .arkboardOpenSettings, object: nil)
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill((store.serverState.isListening ? Hue.moss : Hue.crimson).color(for: scheme))
                        .frame(width: 7, height: 7)
                    Text(store.serverState.isListening ? "Agents · :7420" : "Agents offline")
                        .font(type.caption)
                        .foregroundStyle(StudioColor.secondary)
                    Spacer()
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            .background(.bar)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    NotificationCenter.default.post(name: .arkboardNewProject, object: nil)
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("New Project")
            }
        }
    }
}
