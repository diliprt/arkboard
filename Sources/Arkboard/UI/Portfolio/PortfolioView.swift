import AppKit
import Foundation
import SwiftUI

struct PortfolioView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type

    var body: some View {
        // No in-page title band. The window title bar already says Portfolio,
        // so the cards start at the top of the pane.
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                    if store.projects.isEmpty {
                        EmptyStateView(
                            section: .portfolio,
                            title: EmptyCopy.portfolioEmpty.0,
                            sentence: EmptyCopy.portfolioEmpty.1,
                            actionTitle: "New Project",
                            layout: .poster
                        ) {
                            NotificationCenter.default.post(name: .arkboardNewProject, object: nil)
                        }
                    } else {
                        cards
                    }
                }
                .padding(Metrics.paneX)
                .frame(width: DocumentMeasure.pageWidth(paneWidth: geo.size.width), alignment: .leading)
            }
            .paneBackground(StudioColor.wash(.violet, scheme: scheme))
        }
        .frame(minWidth: Metrics.documentMin, maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    NotificationCenter.default.post(name: .arkboardNewProject, object: nil)
                } label: {
                    SwiftUI.Label("New Project", systemImage: "plus")
                }
                .help("New Project")
            }
        }
        .chiefOfStaffContextMenu()
        .onAppear {
            store.clearOutline()
            store.publishPageFocus(PageFocus(destination: "portfolio"))
        }
    }

    private var cards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: Metrics.cardGap)], spacing: Metrics.cardGap) {
            ForEach(store.projects) { project in
                projectCard(project)
            }
        }
    }

    /// A poster, not a form. The project's own picture is the card face,
    /// full-bleed to the card's rounded corners, with a name and one line of
    /// summary under it. Checkout paths and the four document words are not on
    /// the tile — they are metadata, and metadata is not a poster.
    private func projectCard(_ project: Project) -> some View {
        let bundle = store.documentBundles[project.id]
        let summary = MarkdownParser.cardSummary(
            markdown: bundle?.overview?.markdown,
            name: project.name,
            fallback: project.summary
        )
        return VStack(alignment: .leading, spacing: 0) {
            poster(project)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(project.name).font(type.heading)
                    Spacer(minLength: 8)
                    pinControl(project)
                }
                Text(summary)
                    .font(type.callout)
                    .foregroundStyle(StudioColor.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Metrics.cardPad)
        }
        .font(type.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioColor.card)
        .clipShape(Concentric.shape(Metrics.radiusCard))
        .overlay(
            Concentric.shape(Metrics.radiusCard)
                .stroke(StudioColor.cardStroke(.violet, scheme: scheme), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.sidebarSelection = .project(project.id)
        }
        .contextMenu {
            Button(project.pinned ? "Unpin" : "Pin") {
                store.setProjectPinned(id: project.id, pinned: !project.pinned)
            }
            ChiefOfStaffMenuButton(selectedText: FocusedSelection.currentText())
        }
        .accessibilityLabel("\(project.name), \(project.key). \(summary)")
    }

    /// A fixed-aspect box the card's width, so every card in the grid lines up
    /// whatever picture it is given.
    private func poster(_ project: Project) -> some View {
        Color.clear
            .aspectRatio(Metrics.cardPosterAspect, contentMode: .fit)
            .overlay { posterFace(project) }
            .clipped()
    }

    @ViewBuilder
    private func posterFace(_ project: Project) -> some View {
        if let data = store.cardImage(for: project), let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
        } else {
            // No poster yet: a field in the project's own colour carrying its
            // mark. A placeholder that still looks designed, never a chip.
            let brand = Color(hex: project.color)
            ZStack {
                LinearGradient(
                    colors: [brand.opacity(0.30), brand.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: project.icon.isEmpty ? ProjectMark.symbols[0] : project.icon)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(brand.opacity(0.85))
                    .padding(Metrics.posterGlyphInset)
            }
            .accessibilityHidden(true)
        }
    }

    private func pinControl(_ project: Project) -> some View {
        Button {
            store.setProjectPinned(id: project.id, pinned: !project.pinned)
        } label: {
            SwiftUI.Label(project.pinned ? "Unpin" : "Pin", systemImage: project.pinned ? "pin.fill" : "pin")
                .labelStyle(.iconOnly)
                .font(type.callout)
                .foregroundStyle(project.pinned ? Hue.violet.color(for: scheme) : StudioColor.tertiary)
        }
        .buttonStyle(.plain)
        .help(project.pinned ? "Unpin" : "Pin")
    }
}

extension DocumentTab {
    var section: StudioSection {
        switch self {
        case .design: return .design
        case .architecture: return .architecture
        case .mockups: return .mockups
        case .decisions: return .decisions
        case .overview, .more: return .portfolio
        }
    }
}
