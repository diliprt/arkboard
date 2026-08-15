import SwiftUI

/// The navigation column. It is a plain `.sidebar` list and nothing else: the
/// glass, the row insets, and the selection highlight all come from the system.
/// Anything painted behind this list blocks that glass, so nothing is.
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
                    .padding(.vertical, Metrics.sidebarRowY)
                    .tag(SidebarItem.portfolio)
                    .contextMenu { ChiefOfStaffMenuButton(selectedText: FocusedSelection.currentText()) }
                SwiftUI.Label("Timeline", systemImage: StudioSection.timeline.symbol)
                    .font(type.body)
                    .padding(.vertical, Metrics.sidebarRowY)
                    .tag(SidebarItem.timeline)
                    .contextMenu { ChiefOfStaffMenuButton(selectedText: FocusedSelection.currentText()) }
            }
            Divider()
                .padding(.vertical, Metrics.sidebarRowY)
            Section {
                ForEach(store.pinnedProjects) { project in
                    HStack(spacing: 10) {
                        ProjectIcon(
                            project: project,
                            imageData: store.markImage(for: project),
                            size: Metrics.markSidebar
                        )
                        Text(project.name)
                            .font(type.body)
                        Spacer(minLength: 8)
                        Text(project.key)
                            .font(type.mono)
                            .foregroundStyle(StudioColor.tertiary)
                    }
                    .padding(.vertical, Metrics.sidebarRowY)
                    .tag(SidebarItem.project(project.id))
                    .contextMenu {
                        Button(project.pinned ? "Unpin" : "Pin") {
                            store.setProjectPinned(id: project.id, pinned: !project.pinned)
                        }
                        ChiefOfStaffMenuButton(selectedText: FocusedSelection.currentText())
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .navigationSplitViewColumnWidth(min: Metrics.sidebarMin, ideal: Metrics.sidebarIdeal, max: Metrics.sidebarMax)
        .columnBottomBar(footer)
    }

    /// Onboarding and the agent server sit on the same bar as the list, not in a
    /// widget with its own material.
    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                store.sidebarSelection = .onboarding
            } label: {
                SwiftUI.Label("Onboarding", systemImage: "sparkles")
                    .labelStyle(.iconOnly)
                    .font(type.body)
                    .foregroundStyle(
                        store.sidebarSelection == .onboarding
                            ? Hue.indigo.color(for: scheme)
                            : StudioColor.secondary
                    )
            }
            .buttonStyle(.borderless)
            .help("Onboarding")
            .contextMenu { ChiefOfStaffMenuButton(selectedText: FocusedSelection.currentText()) }
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
        .padding(.vertical, 10)
    }
}
