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

    /// The mark is the hero. Name and one line of summary sit under it, and the
    /// paths and document markers recede to a quiet footer so they never
    /// compete with the mark.
    private func projectCard(_ project: Project) -> some View {
        let bundle = store.documentBundles[project.id]
        let summary = MarkdownParser.cardSummary(
            markdown: bundle?.overview?.markdown,
            name: project.name,
            fallback: project.summary
        )
        return CardSurface(hue: .violet) {
            VStack(alignment: .leading, spacing: 16) {
                ProjectIcon(
                    project: project,
                    imageData: store.markImage(for: project),
                    size: Metrics.markHero
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(project.name).font(type.heading)
                        Text(project.key).font(type.mono).foregroundStyle(StudioColor.tertiary)
                        Spacer(minLength: 8)
                        pinControl(project)
                    }
                    Text(summary)
                        .font(type.callout)
                        .foregroundStyle(StudioColor.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    if let path = project.repoPath, !path.isEmpty {
                        Text("local · \(Self.displayPath(path))")
                            .font(type.mono)
                            .foregroundStyle(StudioColor.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let repo = project.githubRepo, !repo.isEmpty {
                        Text("github · \(repo)")
                            .font(type.mono)
                            .foregroundStyle(StudioColor.tertiary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 10) {
                        docPill("Design", .design, bundle)
                        docPill("Architecture", .architecture, bundle)
                        docPill("Mockups", .mockups, bundle)
                        docPill("Decisions", .decisions, bundle)
                    }
                }
            }
            .font(type.body)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    /// One quiet word per document, coloured when that document exists and
    /// dimmed when it does not. No capsule fill — on a card led by the mark,
    /// four filled chips are the loudest thing on screen, which is backwards.
    private func docPill(_ label: String, _ tab: DocumentTab, _ bundle: DocumentBundle?) -> some View {
        let exists: Bool
        if tab == .mockups {
            exists = bundle?.documents.contains { $0.tab == tab } == true
        } else {
            exists = bundle?.documents.contains { $0.tab == tab && !$0.isImage } == true
        }
        return Text(label)
            .font(type.caption)
            .foregroundStyle(
                exists
                    ? tab.section.hue.color(for: scheme)
                    : StudioColor.tertiary
            )
            .opacity(exists ? 1 : 0.6)
    }

    private static func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
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
