import Foundation
import SwiftUI

struct PortfolioView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScreenHeader(
                    section: .portfolio,
                    subtitle: "Every project at arm's length.",
                    trailing: AnyView(
                        Button {
                            NotificationCenter.default.post(name: .arkboardNewProject, object: nil)
                        } label: {
                            SwiftUI.Label("New Project", systemImage: "folder.badge.plus")
                                .font(type.body)
                        }
                        .buttonStyle(.plain)
                    )
                )
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
                .background(StudioColor.wash(.violet, scheme: scheme))
            }
        }
        .frame(minWidth: Metrics.documentMin, maxWidth: .infinity, maxHeight: .infinity)
        .chiefOfStaffContextMenu()
        .onAppear {
            store.clearOutline()
            store.publishPageFocus(PageFocus(destination: "portfolio"))
        }
    }

    private var cards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 460), spacing: 12)], spacing: 12) {
            ForEach(store.projects) { project in
                projectCard(project)
            }
        }
    }

    private func projectCard(_ project: Project) -> some View {
        let bundle = store.documentBundles[project.id]
        let summary = MarkdownParser.cardSummary(
            markdown: bundle?.overview?.markdown,
            name: project.name,
            fallback: project.summary
        )
        return CardSurface(hue: .violet) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ProjectIcon(project: project, imageData: store.markImage(for: project), size: 22)
                    Text(project.name).font(type.heading)
                    Text(project.key).font(type.mono).foregroundStyle(StudioColor.secondary)
                    Spacer()
                    Button {
                        store.setProjectPinned(id: project.id, pinned: !project.pinned)
                    } label: {
                        Image(systemName: project.pinned ? "pin.fill" : "pin")
                            .foregroundStyle(project.pinned ? Hue.violet.color(for: scheme) : StudioColor.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(project.pinned ? "Unpin" : "Pin")
                }
                Text(summary)
                    .font(type.callout)
                    .foregroundStyle(StudioColor.secondary)
                    .lineLimit(2)
                VStack(alignment: .leading, spacing: 4) {
                    if let path = project.repoPath, !path.isEmpty {
                        Text("local · \(Self.displayPath(path))")
                            .font(type.mono)
                            .foregroundStyle(StudioColor.secondary)
                            .lineLimit(1)
                    }
                    if let repo = project.githubRepo, !repo.isEmpty {
                        Text("github · \(repo)")
                            .font(type.mono)
                            .foregroundStyle(StudioColor.secondary)
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 6) {
                    docPill("Design", .design, bundle)
                    docPill("Architecture", .architecture, bundle)
                    docPill("Mockups", .mockups, bundle)
                    docPill("Decisions", .decisions, bundle)
                }
            }
            .font(type.body)
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

    private func docPill(_ label: String, _ tab: DocumentTab, _ bundle: DocumentBundle?) -> some View {
        let exists: Bool
        if tab == .mockups {
            exists = bundle?.documents.contains { $0.tab == tab } == true
        } else {
            exists = bundle?.documents.contains { $0.tab == tab && !$0.isImage } == true
        }
        return Text(label)
            .font(type.caption)
            .foregroundStyle(exists ? tab.section.hue.color(for: scheme) : Hue.slate.color(for: scheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                exists ? StudioColor.chipFill(tab.section.hue, scheme: scheme) : Color.clear,
                in: Capsule()
            )
            .overlay(Capsule().stroke(exists ? Color.clear : Hue.slate.color(for: scheme).opacity(0.4), lineWidth: 1))
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
