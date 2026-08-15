import AppKit
import SwiftUI

enum ProjectHomeAnchor {
    /// The top of the tab body. Not the rail: the rail is a pinned header, and
    /// a pinned view is not a stable scroll target.
    static let tabTop = "tab-top"
}

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

    var handoffTitle: String {
        switch self {
        case .design: return "Design"
        case .architecture: return "Architecture"
        case .mockups: return "Mockups"
        case .decisions: return "Decisions"
        case .issues: return "Issues"
        case .timeline: return "Timeline"
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
        // The tab rail is the first thing in the scroll, so it is pinned from
        // the moment the page paints and there is nothing above it that can
        // push it around. Nothing here animates geometry on a tab change: an
        // eased height change plus a programmatic scroll is what made the pane
        // bounce when the gallery measured itself a frame late.
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            ZStack(alignment: .topLeading) {
                                StudioColor.wash(tab.section.hue, scheme: scheme)
                                tabBody
                                    .padding(.horizontal, Metrics.paneX)
                                    .padding(.trailing, readingGutter)
                                    .padding(.vertical, Metrics.paneY)
                            }
                            .frame(maxWidth: .infinity, minHeight: Metrics.emptyPaneMin, alignment: .topLeading)
                            .id(ProjectHomeAnchor.tabTop)
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
                .onChange(of: tab) { _, _ in
                    publishOutline()
                    publishFocus()
                    restTop(proxy)
                }
                .onAppear { restTop(proxy) }
            }
        }
        .frame(minWidth: Metrics.documentMin, maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .toolbar { identityToolbar }
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
            publishFocus()
        }
        .onChange(of: selectedPath) { _, _ in
            publishOutline()
            publishFocus()
        }
        .onChange(of: bundle?.loadedAt) { _, _ in
            publishOutline()
            publishFocus()
        }
        .chiefOfStaffContextMenu()
        .onChange(of: store.pendingProjectTab) { _, next in
            if let next {
                tab = next
                store.pendingProjectTab = nil
            }
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

    /// Identity lives in the window title bar, beside the title that already
    /// names the project. There is no second logo row under it, so the pane
    /// starts at the tab rail.
    @ToolbarContentBuilder
    private var identityToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 8) {
                ProjectIcon(project: project, imageData: store.markImage(for: project), size: Metrics.markSidebar)
                Text(project.key)
                    .font(type.mono)
                    .foregroundStyle(StudioColor.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(project.name), \(project.key)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await store.refreshDocuments(projectId: project.id) }
            } label: {
                SwiftUI.Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Reload \(sourceLabel)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                store.goToComposer()
            } label: {
                SwiftUI.Label("Note", systemImage: "bubble.left")
            }
            .help(ChiefOfStaffCopy.menuTitle)
            // RootView presents ProjectNoteSheet for this action and for ⌘N.
        }
    }

    /// Contents floats over the trailing edge, so the prose stops short of it.
    /// The page still measures the whole pane; only the text is inset.
    private var readingGutter: CGFloat {
        store.readingGutter(showsContents: true)
    }

    /// One rule for every tab: the page returns to the top of the tab content.
    /// The anchor is the section body, never the pinned rail — a pinned view is
    /// being repositioned by the scroll view itself, so scrolling *to* it
    /// chases a moving target, which is the jump. Animations are off so a late
    /// layout pass cannot fight an in-flight scroll.
    private func restTop(_ proxy: ScrollViewProxy) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(ProjectHomeAnchor.tabTop, anchor: .top)
        }
    }

    private var sourceLabel: String {
        if let source = bundle?.source, source == "github", let repo = project.githubRepo {
            return "github · \(repo)"
        }
        return "local · product/"
    }

    /// The tab rail is navigation, so it is a row of native accessory-bar
    /// capsules on the glass layer — one system selected state per tab, no
    /// hand-drawn pill. The section wash tints that glass and nothing opaque
    /// sits behind it.
    private var tabBar: some View {
        ScrollViewReader { tabProxy in
            FadingHScroll {
                HStack(spacing: 6) {
                    ForEach(ProjectHomeTab.allCases) { item in
                        Toggle(isOn: selection(for: item)) {
                            SwiftUI.Label(item.section.title, systemImage: item.section.symbol)
                                .font(type.body)
                        }
                        .filterCapsule()
                        .tint(item.section.hue.color(for: scheme))
                        .id(item.id)
                    }
                }
                .padding(.horizontal, Metrics.paneX)
                .padding(.trailing, readingGutter)
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
        .navigationBarSurface(tint: StudioColor.wash(tab.section.hue, scheme: scheme))
        .chiefOfStaffContextMenu()
    }

    private func selection(for item: ProjectHomeTab) -> Binding<Bool> {
        Binding(
            get: { tab == item },
            set: { isSelected in
                guard isSelected else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    tab = item
                    selectedPath = nil
                }
            }
        )
    }

    private func selection(forDocumentAt path: String) -> Binding<Bool> {
        Binding(
            get: { (selectedPath ?? currentDocument?.path) == path },
            set: { isSelected in
                guard isSelected else { return }
                selectedPath = path
            }
        )
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
                TimelineGanttView(projectId: project.id)
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
                            HStack(spacing: 6) {
                                ForEach(docs) { doc in
                                    Toggle(doc.title, isOn: selection(forDocumentAt: doc.path))
                                        .filterCapsule()
                                        .tint(tab.section.hue.color(for: scheme))
                                        .font(type.body)
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
                        MarkdownView(
                            markdown: markdown,
                            hue: tab.section.hue,
                            suppressedTitle: tab.section.title,
                            onLink: handleLink
                        )
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
                // Every cell is the same known height, so the grid's height is
                // settled at first layout instead of growing as thumbnails
                // materialise. A gallery that resizes after paint is what
                // shoves the pane around when you land on this tab.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                    ForEach(images) { image in
                        Button { viewer = image } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Concentric.shape(Metrics.radiusCard)
                                    .fill(StudioColor.card)
                                    .frame(height: Metrics.mockupThumb)
                                    .overlay {
                                        if let data = image.imageData, let ns = NSImage(data: data) {
                                            Image(nsImage: ns).resizable().scaledToFit()
                                        }
                                    }
                                Text(image.title)
                                    .font(type.caption)
                                    .foregroundStyle(StudioColor.secondary)
                                    .lineLimit(1)
                            }
                            .frame(height: Metrics.mockupCell, alignment: .top)
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
                        Text(group.rawValue)
                            .font(type.caption)
                            .foregroundStyle(Hue.teal.color(for: scheme))
                        ForEach(rows) { issue in
                            IssueRowView(issue: issue, showProject: false)
                                .onTapGesture {
                                    store.selectedIssueID = issue.id
                                }
                                .contextMenu {
                                    ChiefOfStaffMenuButton(selectedText: FocusedSelection.currentText())
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
            store.publishOutline(
                headings: MarkdownParser.headings(in: markdown, suppressingTitle: tab.section.title),
                hue: tab.section.hue
            )
        } else {
            store.publishOutline(headings: [], hue: tab.section.hue)
        }
    }

    private func publishFocus() {
        store.publishPageFocus(PageFocus(
            destination: "project",
            projectKey: project.key,
            projectName: project.name,
            tab: tab.handoffTitle,
            documentPath: currentDocument?.path,
            markdown: currentDocument?.markdown
        ))
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
