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
            }
            Divider()
            Section {
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
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: Metrics.sidebarMin, ideal: Metrics.sidebarIdeal, max: Metrics.sidebarMax)
        .safeAreaInset(edge: .bottom) {
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
            .padding(12)
            .background(.bar)
        }
    }
}
