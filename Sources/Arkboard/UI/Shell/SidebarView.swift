import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type

    var body: some View {
        @Bindable var store = store
        List(selection: $store.sidebarSelection) {
            Section {
                SwiftUI.Label("Portfolio", systemImage: StudioSection.portfolio.symbol)
                    .font(type.body)
                    .tag(SidebarItem.portfolio)
                SwiftUI.Label("Timeline", systemImage: StudioSection.timeline.symbol)
                    .font(type.body)
                    .tag(SidebarItem.timeline)
                ForEach(store.pinnedProjects) { project in
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
                    .contextMenu {
                        Button(project.pinned ? "Unpin" : "Pin") {
                            store.setProjectPinned(id: project.id, pinned: !project.pinned)
                        }
                    }
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
                HStack(spacing: 8) {
                    Button {
                        store.sidebarSelection = .onboarding
                    } label: {
                        Image(systemName: "sparkles")
                            .font(type.body)
                            .foregroundStyle(
                                store.sidebarSelection == .onboarding
                                    ? Hue.indigo.color(for: scheme)
                                    : StudioColor.secondary
                            )
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Onboarding")
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .background(.bar)
        }
    }
}
