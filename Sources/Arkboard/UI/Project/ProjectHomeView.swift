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
    @State private var showNoteSheet = false

    var bundle: DocumentBundle? { store.documentBundles[project.id] }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        projectHeader
                        Section {
                            ZStack(alignment: .topLeading) {
                                StudioColor.wash(tab.section.hue, scheme: scheme)
                                tabBody
                                    .padding(.horizontal, Metrics.paneX)
                                    .padding(.vertical, Metrics.paneY)
                            }
                            .frame(maxWidth: .infinity, minHeight: Metrics.emptyPaneMin, alignment: .topLeading)
                            .id("tab-top")
                        } header: {
                            tabBar
                                .id("tab-bar")
                        }
                    }
                    .frame(width: DocumentMeasure.pageWidth(paneWidth: geo.size.width), alignment: .leading)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .onChange(of: store.documentOutline.jumpToken) { _, _ in
                    if let anchor = store.documentOutline.pendingAnchor {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            proxy.scrollTo(anchor, anchor: .top)
                        }
                    }
                }
                .onChange(of: store.focusComposer) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        proxy.scrollTo("composer", anchor: .center)
                    }
                }
                .onChange(of: tab) { _, newTab in
                    publishOutline()
                    if newTab == .mockups {
                        proxy.scrollTo("tab-bar", anchor: .top)
                    }
                }
                .onAppear {
                    if tab == .mockups {
                        proxy.scrollTo("tab-bar", anchor: .top)
                    }
                }
            }
        }
        .frame(minWidth: Metrics.documentMin, maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
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
        .task(id: project.id) {
            await store.ensureDocuments(projectId: project.id)
        }
        .onAppear {
            if let id = store.selectedIssueID, let issue = store.issue(idOrIdentifier: id), issue.projectId != project.id {
                store.selectedIssueID = nil
            }
            publishOutline()
        }
        .onChange(of: selectedPath) { _, _ in publishOutline() }
        .onChange(of: bundle?.loadedAt) { _, _ in publishOutline() }
        .onChange(of: store.pendingProjectTab) { _, next in
            if let next {
                tab = next
                store.pendingProjectTab = nil
            }
        }
        .onChange(of: store.focusComposer) { _, _ in
            showNoteSheet = true
        }
        .sheet(isPresented: $showNoteSheet) {
            ProjectNoteSheet(project: project)
        }
        .sheet(item: issueSheet) { _ in
            IssueDetailColumn()
                .frame(minWidth: 640, minHeight: 520)
        }
    }

    private var issueSheet: Binding<Issue?> {
        Binding(
            get: { store.selectedIssueID.flatMap { store.issue(idOrIdentifier: $0) } },
            set: { store.selectedIssueID = $0?.id }
        )
    }

    private var projectHeader: some View {
        ProseColumn {
            HStack(alignment: .firstTextBaseline) {
                ProjectIcon(project: project, imageData: store.markImage(for: project), size: 28)
                Text(project.name).font(type.display)
                Chip(text: project.key, hue: .slate, mono: true)
                Spacer()
                Text(sourceLabel)
                    .font(type.mono)
                    .foregroundStyle(StudioColor.secondary)
                Button {
                    Task { await store.refreshDocuments(projectId: project.id) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
                Button {
                    showNoteSheet = true
                } label: {
                    Image(systemName: "bubble.left")
                }
                .buttonStyle(.plain)
                .help("Note")
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
        GeometryReader { geo in
            let compact = geo.size.width < Metrics.tabCompactWidth
            ScrollViewReader { tabProxy in
                FadingHScroll {
                    HStack(spacing: 6) {
                        ForEach(ProjectHomeTab.allCases) { item in
                            Button {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                                    tab = item
                                    selectedPath = nil
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if tab == item || !compact {
                                        Image(systemName: item.section.symbol)
                                    }
                                    Text(item.section.title)
                                }
                                .font(type.caption)
                                .foregroundStyle(tab == item ? item.section.hue.color(for: scheme) : StudioColor.secondary)
                                .padding(.horizontal, Metrics.tabPillX)
                                .padding(.vertical, 6)
                                .background(tab == item ? StudioColor.selectedTab(item.section.hue, scheme: scheme) : Color.clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, Metrics.paneX)
                    .padding(.vertical, 8)
                }
                .onChange(of: tab) { _, newTab in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        tabProxy.scrollTo(newTab.id, anchor: .center)
                    }
                }
                .onAppear {
                    tabProxy.scrollTo(tab.id, anchor: .center)
                }
            }
        }
        .frame(height: Metrics.tabBarHeight)
        .background {
            ZStack {
                StudioColor.window
                StudioColor.wash(tab.section.hue, scheme: scheme)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioColor.hairline)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var tabBody: some View {
        ProseColumn {
            switch tab {
            case .design, .architecture, .decisions:
                documentTab
            case .mockups:
                mockupsTab
            case .issues:
                projectIssues
            case .timeline:
                TimelineCalendarView(projectId: project.id)
            }
        }
    }

    @ViewBuilder
    private var documentTab: some View {
        if let error = bundle?.error {
            EmptyStateView(section: tab.section, title: "Documents could not be read", sentence: error, actionTitle: "Try again", minHeight: Metrics.emptyPaneMin) {
                Task { await store.refreshDocuments(projectId: project.id) }
            }
        } else if let documentTab = tab.documentTab {
            let docs = (bundle?.documents(in: documentTab) ?? []).filter { !$0.isImage }
            if docs.isEmpty {
                let copy = emptyCopy
                EmptyStateView(section: tab.section, title: copy.0, sentence: copy.1, minHeight: Metrics.emptyPaneMin)
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
                            FlowLayout(spacing: 8) {
                                ForEach(opens, id: \.anchor) { question in
                                    Button {
                                        store.jumpToHeading(question.anchor)
                                    } label: {
                                        Chip(text: question.heading, hue: .gold)
                                    }
                                    .buttonStyle(.plain)
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
        let flow = mockupFlow(for: images)
        return VStack(alignment: .leading, spacing: 20) {
            if images.isEmpty {
                EmptyStateView(section: .mockups, title: EmptyCopy.mockups.0, sentence: EmptyCopy.mockups.1, minHeight: Metrics.emptyPaneMin)
            } else {
                if !flow.nodes.isEmpty {
                    mockupFlowRail(flow, images: images)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                    ForEach(images) { image in
                        Button { viewer = image } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                                    .fill(StudioColor.card)
                                    .frame(height: 260)
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
            }
        }
    }

    private func mockupFlow(for images: [StudioDocument]) -> MockupFlow {
        let docs = bundle?.documents(in: .mockups) ?? []
        let json = docs.first { DocumentRouting.isFlowJSON($0.path) }?.markdown
        let markdown = docs.first { DocumentRouting.isFlowDocument($0.path) && !DocumentRouting.isFlowJSON($0.path) }?.markdown
        return MockupFlowParser.parse(
            flowJSON: json,
            flowMarkdown: markdown,
            imageNames: images.map(\.path)
        )
    }

    private func mockupFlowRail(_ flow: MockupFlow, images: [StudioDocument]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Screen flow")
                    .font(type.caption)
                    .foregroundStyle(StudioColor.secondary)
                if flow.inferred {
                    Text("Inferred from filenames")
                        .font(type.caption)
                        .foregroundStyle(StudioColor.tertiary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(flow.nodes.enumerated()), id: \.element.id) { index, node in
                        Button {
                            if let match = images.first(where: { DocumentRouting.stem($0.path) == node.id.lowercased() || $0.title.caseInsensitiveCompare(node.title) == .orderedSame }) {
                                viewer = match
                            }
                        } label: {
                            Chip(text: node.title, hue: .magenta)
                        }
                        .buttonStyle(.plain)
                        if index < flow.nodes.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(type.caption)
                                .foregroundStyle(StudioColor.tertiary)
                        }
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
                EmptyStateView(section: .issues, title: EmptyCopy.noIssues.0, sentence: EmptyCopy.noIssues.1, minHeight: Metrics.emptyPaneMin)
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

    private func publishOutline() {
        if let markdown = currentDocument?.markdown {
            store.publishOutline(headings: MarkdownParser.headings(in: markdown), hue: tab.section.hue)
        } else {
            store.publishOutline(headings: [], hue: tab.section.hue)
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
        if destination.hasPrefix("#") {
            store.jumpToHeading(String(destination.dropFirst()))
            return
        }
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
