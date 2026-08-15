import SwiftUI

struct PortfolioView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(section: .portfolio, subtitle: "Every project at arm's length.")
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                    totals
                    if store.projects.isEmpty {
                        EmptyStateView(section: .portfolio, title: EmptyCopy.portfolioEmpty.0, sentence: EmptyCopy.portfolioEmpty.1)
                    } else {
                        cards
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Milestones").font(type.heading)
                        TimelineSpine(events: TimelineBuilder.events(milestones: store.milestones, issues: store.issues.filter { $0.status == .done }))
                    }
                }
                .padding(Metrics.paneX)
                .frame(maxWidth: Metrics.gridMax, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(StudioColor.wash(.violet, scheme: scheme))
        }
    }

    private var totals: some View {
        HStack(spacing: 12) {
            total("Projects", store.projects.count)
            total("Open issues", store.issues.filter { $0.archivedAt == nil && $0.status != .done && $0.status != .canceled }.count)
            total("Questions waiting", store.openQuestions.count)
            total("Not working", store.brokenCapabilities.count)
        }
    }

    private func total(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)").font(type.title)
            Text(label).font(type.caption)
        }
        .padding(Metrics.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioColor.chipFill(.violet, scheme: scheme), in: RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
        .foregroundStyle(Hue.violet.color(for: scheme))
    }

    private var cards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 460), spacing: 12)], spacing: 12) {
            ForEach(store.projects) { project in
                Button {
                    store.sidebarSelection = .project(project.id)
                } label: {
                    projectCard(project)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func projectCard(_ project: Project) -> some View {
        let bundle = store.documentBundles[project.id]
        let grouped = store.humanIssues(projectId: project.id)
        let questions = store.openQuestions.filter { $0.projectId == project.id }.count
        let broken = store.capabilities.filter { $0.projectId == project.id && $0.health == .notWorking }.count
        let next = store.milestones.filter { $0.projectId == project.id && $0.status != .done }.sorted { $0.targetDate < $1.targetDate }.first
        let summary = bundle?.overview.flatMap { $0.markdown }.map { MarkdownParser.firstSentence($0) } ?? project.summary
        return CardSurface(hue: .violet) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ProjectDot(hex: project.color, size: 10)
                    Text(project.name).font(type.heading)
                    Text(project.key).font(type.mono).foregroundStyle(StudioColor.secondary)
                }
                Text(summary)
                    .font(type.callout)
                    .foregroundStyle(StudioColor.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    docPill("Design", .design, bundle)
                    docPill("Architecture", .architecture, bundle)
                    docPill("Mockups", .mockups, bundle)
                    docPill("Decisions", .decisions, bundle)
                }
                Text("Underway \(grouped[.underway, default: []].count) · Queued \(grouped[.queued, default: []].count) · Done \(grouped[.done, default: []].count)")
                    .font(type.caption)
                    .foregroundStyle(StudioColor.secondary)
                if let next {
                    HStack(spacing: 6) {
                        ProjectDot(hex: (next.status == .inProgress ? Hue.gold : Hue.moss).light, size: 6)
                        Text(next.title).font(type.caption)
                        Text(next.targetDate, style: .date).font(type.caption).foregroundStyle(StudioColor.secondary)
                    }
                }
                HStack {
                    if questions > 0 { Chip(text: "\(questions) questions", hue: .gold) }
                    if broken > 0 { Chip(text: "\(broken) not working", hue: .crimson) }
                }
            }
        }
    }

    private func docPill(_ label: String, _ tab: DocumentTab, _ bundle: DocumentBundle?) -> some View {
        let exists = bundle?.documents.contains { $0.tab == tab && !$0.isImage } == true
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
