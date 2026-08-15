import AppKit
import SwiftUI

enum ProjectHomeTab: String, CaseIterable, Identifiable {
    case design, architecture, mockups, decisions, issues, timeline
    var id: String { rawValue }
    var section: StudioSection {
        switch self {
        case .design: return .design
        case .architecture: return .architecture
        case .mockups: return .mockups
        case .decisions: return .decisions
        case .issues: return .issues
        case .timeline: return .timeline
        }
    }
    var documentTab: DocumentTab? {
        switch self {
        case .design: return .design
        case .architecture: return .architecture
        case .mockups: return .mockups
        case .decisions: return .decisions
        default: return nil
        }
    }
}

struct ProjectHomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var project: Project
    @State private var tab: ProjectHomeTab = .design
    @State private var selectedPath: String?
    @State private var viewer: StudioDocument?

    var bundle: DocumentBundle? { store.documentBundles[project.id] }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    overview
                    Section {
                        tabBody
                            .padding(.horizontal, Metrics.paneX)
                            .padding(.vertical, Metrics.paneY)
                            .id("tab-top")
                    } header: {
                        VStack(spacing: 0) {
                            tabBar
                            outline(proxy: proxy)
                        }
                        .background(StudioColor.window)
                    }
                }
            }
        }
        .background(StudioColor.wash(tab.section.hue, scheme: scheme))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: tab)
        .sheet(item: $viewer) { document in
            MockupViewer(documents: mockupImages, current: document)
        }
        .onReceive(NotificationCenter.default.publisher(for: .arkboardTabPrev)) { _ in
            cycleTab(-1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .arkboardTabNext)) { _ in
            cycleTab(1)
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                ProjectDot(hex: project.color, size: 10)
                Text(project.name).font(type.display)
                Chip(text: project.key, hue: .slate, mono: true)
                Spacer()
                Text(sourceLabel)
                    .font(type.mono)
                    .foregroundStyle(StudioColor.secondary)
                if let loaded = bundle?.loadedAt {
                    Text("loaded \(RelativeTime.format(loaded))")
                        .font(type.caption)
                        .foregroundStyle(StudioColor.secondary)
                }
                Button {
                    Task { await store.refreshDocuments(projectId: project.id) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            if let error = bundle?.error {
                EmptyStateView(section: .design, title: "Documents could not be read", sentence: error, actionTitle: "Try again") {
                    Task { await store.refreshDocuments(projectId: project.id) }
                }
            } else if let markdown = bundle?.overview?.markdown, !markdown.isEmpty {
                MarkdownView(markdown: MarkdownParser.lead(beforeFirstH2: markdown), hue: .slate, onLink: handleLink)
            } else {
                EmptyStateView(section: .portfolio, title: EmptyCopy.overview.0, sentence: EmptyCopy.overview.1)
            }
            if let more = bundle?.moreDocuments, !more.isEmpty {
                HStack {
                    Text("More documents").font(type.caption).foregroundStyle(StudioColor.secondary)
                    ForEach(more) { doc in
                        Chip(text: doc.title, hue: .slate)
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.paneX)
        .padding(.vertical, Metrics.paneY)
        .background(StudioColor.window)
    }

    private var sourceLabel: String {
        if let source = bundle?.source, source == "github", let repo = project.githubRepo {
            return "github · \(repo)"
        }
        return "local · product/"
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ProjectHomeTab.allCases) { item in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                            tab = item
                            selectedPath = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.section.symbol)
                            Text(item.section.title)
                        }
                        .font(type.caption)
                        .foregroundStyle(tab == item ? item.section.hue.color(for: scheme) : StudioColor.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(tab == item ? StudioColor.selectedTab(item.section.hue, scheme: scheme) : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.paneX)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func outline(proxy: ScrollViewProxy) -> some View {
        if let document = currentDocument, let markdown = document.markdown {
            let headings = MarkdownParser.headings(in: markdown)
            if headings.count >= 2 {
                OutlineBar(headings: headings, hue: tab.section.hue) { anchor in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        proxy.scrollTo(anchor, anchor: .top)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tabBody: some View {
        switch tab {
        case .design, .architecture, .decisions:
            documentTab
        case .mockups:
            mockupsTab
        case .issues:
            projectIssues
        case .timeline:
            TimelineSpine(
                events: TimelineBuilder.events(
                    milestones: store.milestones.filter { $0.projectId == project.id },
                    issues: store.issues.filter { $0.projectId == project.id && $0.status == .done }
                )
            )
        }
    }

    @ViewBuilder
    private var documentTab: some View {
        if let error = bundle?.error {
            EmptyStateView(section: tab.section, title: "Documents could not be read", sentence: error, actionTitle: "Try again") {
                Task { await store.refreshDocuments(projectId: project.id) }
            }
        } else if let documentTab = tab.documentTab {
            let docs = (bundle?.documents(in: documentTab) ?? []).filter { !$0.isImage }
            if docs.isEmpty {
                let copy = emptyCopy
                EmptyStateView(section: tab.section, title: copy.0, sentence: copy.1)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if docs.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(docs) { doc in
                                    Button(doc.title) { selectedPath = doc.path }
                                        .buttonStyle(.plain)
                                        .font(type.caption)
                                        .foregroundStyle((selectedPath ?? currentDocument?.path) == doc.path ? tab.section.hue.color(for: scheme) : StudioColor.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(StudioColor.chipFill(tab.section.hue, scheme: scheme).opacity((selectedPath ?? currentDocument?.path) == doc.path ? 1 : 0), in: Capsule())
                                }
                            }
                        }
                    }
                    if tab == .decisions, let markdown = currentDocument?.markdown {
                        let opens = QuestionParser.openQuestions(in: markdown)
                        if !opens.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(opens, id: \.anchor) { question in
                                        Chip(text: question.heading, hue: .gold)
                                    }
                                }
                            }
                        }
                    }
                    if let markdown = currentDocument?.markdown {
                        MarkdownView(markdown: markdown, hue: tab.section.hue, onLink: handleLink)
                    }
                }
            }
        }
    }

    private var mockupsTab: some View {
        let images = mockupImages
        let notes = (bundle?.documents(in: .mockups) ?? []).filter { !$0.isImage }
        return VStack(alignment: .leading, spacing: 16) {
            if images.isEmpty && notes.isEmpty {
                EmptyStateView(section: .mockups, title: EmptyCopy.mockups.0, sentence: EmptyCopy.mockups.1)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    ForEach(images) { image in
                        Button { viewer = image } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                                    .fill(StudioColor.card)
                                    .frame(height: 180)
                                    .overlay {
                                        if let data = image.imageData, let ns = NSImage(data: data) {
                                            Image(nsImage: ns).resizable().scaledToFit()
                                        }
                                    }
                                Text(image.title).font(type.caption).foregroundStyle(StudioColor.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                ForEach(notes) { note in
                    if let markdown = note.markdown {
                        MarkdownView(markdown: markdown, hue: .magenta, onLink: handleLink)
                    }
                }
            }
        }
    }

    private var projectIssues: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracking only. Agents file and update these.")
                .font(type.callout)
                .foregroundStyle(StudioColor.secondary)
            let grouped = store.humanIssues(projectId: project.id)
            if grouped.values.allSatisfy(\.isEmpty) {
                EmptyStateView(section: .issues, title: EmptyCopy.noIssues.0, sentence: EmptyCopy.noIssues.1)
            } else {
                ForEach([HumanIssueGroup.underway, .queued, .done], id: \.self) { group in
                    let rows = grouped[group, default: []]
                    if !rows.isEmpty {
                        Text(group.rawValue.uppercased())
                            .font(type.caption)
                            .foregroundStyle(Hue.teal.color(for: scheme))
                        ForEach(rows) { issue in
                            IssueRowView(issue: issue, showProject: false)
                                .onTapGesture {
                                    store.selectedIssueID = issue.id
                                    store.sidebarSelection = .issues
                                }
                        }
                    }
                }
            }
        }
    }

    private var currentDocument: StudioDocument? {
        guard let documentTab = tab.documentTab else { return nil }
        let docs = (bundle?.documents(in: documentTab) ?? []).filter { !$0.isImage }
        if let selectedPath, let match = docs.first(where: { $0.path == selectedPath }) { return match }
        return bundle?.primary(in: documentTab)
    }

    private var mockupImages: [StudioDocument] {
        (bundle?.documents(in: .mockups) ?? []).filter(\.isImage)
    }

    private var emptyCopy: (String, String) {
        switch tab {
        case .design: return EmptyCopy.design
        case .architecture: return EmptyCopy.architecture
        case .decisions: return EmptyCopy.decisions
        default: return EmptyCopy.overview
        }
    }

    private func cycleTab(_ delta: Int) {
        let all = ProjectHomeTab.allCases
        guard let index = all.firstIndex(of: tab) else { return }
        let next = (index + delta + all.count) % all.count
        tab = all[next]
        selectedPath = nil
    }

    private func handleLink(_ destination: String) {
        if destination.hasPrefix("http://") || destination.hasPrefix("https://") {
            if let url = URL(string: destination) { NSWorkspace.shared.open(url) }
            return
        }
        if destination.hasPrefix("#") { return }
        let path = destination.contains("product/") ? destination : "product/" + destination
        switch DocumentRouting.tab(for: path) {
        case .design: tab = .design
        case .architecture: tab = .architecture
        case .mockups: tab = .mockups
        case .decisions: tab = .decisions
        default: break
        }
        selectedPath = path
    }
}

struct MockupViewer: View {
    var documents: [StudioDocument]
    var current: StudioDocument
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        VStack {
            if let data = documents[safe: index]?.imageData, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFit()
            }
            Text(documents[safe: index]?.title ?? current.title)
            HStack {
                Button("Previous") { index = max(0, index - 1) }
                Button("Next") { index = min(documents.count - 1, index + 1) }
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 520)
        .onAppear { index = documents.firstIndex(of: current) ?? 0 }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
