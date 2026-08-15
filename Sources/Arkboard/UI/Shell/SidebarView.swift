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
                destinationRow("Portfolio", section: .portfolio)
                    .tag(SidebarItem.portfolio)
                    .contextMenu { ChiefOfStaffMenuButton(selectedText: FocusedSelection.currentText()) }
                destinationRow("Timeline", section: .timeline)
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
                            .foregroundStyle(StudioColor.primary)
                        Spacer(minLength: 8)
                        Text(project.key)
                            .font(type.mono)
                            .foregroundStyle(StudioColor.secondary)
                    }
                    .padding(.vertical, Metrics.sidebarRowY)
                    .quietSelection()
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

    /// Destination rows share the project rows' leading column, so the symbols
    /// and the marks below them line up. Every colour is stated, so nothing is
    /// forced to white by a selection state.
    private func destinationRow(_ title: String, section: StudioSection) -> some View {
        HStack(spacing: 10) {
            Image(systemName: section.symbol)
                .font(type.body)
                .foregroundStyle(section.hue.color(for: scheme))
                .frame(width: Metrics.markSidebar)
            Text(title)
                .font(type.body)
                .foregroundStyle(StudioColor.primary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Metrics.sidebarRowY)
        .quietSelection()
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
