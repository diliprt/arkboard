import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type

    var body: some View {
        @Bindable var store = store
        List(selection: $store.sidebarSelection) {
            Section {
                ForEach(store.projects) { project in
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
                    .tag(SidebarItem.project(project.id))
                }
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: "building.2")
                    Text(store.workspace?.name ?? "Origin Ark")
                }
                .font(type.caption)
                .foregroundStyle(StudioColor.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: Metrics.sidebarMin, ideal: Metrics.sidebarIdeal, max: Metrics.sidebarMax)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button {
                    NotificationCenter.default.post(name: .arkboardNewProject, object: nil)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                        Text("New Project")
                            .font(type.body)
                        Spacer()
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New Project")
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(.bar)
        }
    }
}
