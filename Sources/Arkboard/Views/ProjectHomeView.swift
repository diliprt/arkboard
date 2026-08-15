import SwiftUI

enum ProjectTab: String, CaseIterable, Identifiable {
    case design, architecture, mockups, decisions, issues, timeline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .design: return "Design"
        case .architecture: return "Architecture"
        case .mockups: return "Mockups"
        case .decisions: return "Decisions & questions"
        case .issues: return "Issues"
        case .timeline: return "Timeline"
        }
    }

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
}

struct ProjectHomeView: View {
    @Environment(AppStore.self) private var store
    let project: Project

    @State private var tab: ProjectTab = .design
    @State private var noteDraft = ""
    @State private var selectedIssue: Issue?

    private var tree: ProductTree? {
        store.productLibrary.tree(for: project)
    }

    var body: some View {
        VStack(spacing: 0) {
            overview
            tabBar
            Divider()
            tabBody
        }
        .sectionWash(tab.section)
        .task(id: project.id) {
            await store.productLibrary.load(for: project)
        }
        .sheet(item: $selectedIssue) { issue in
            IssueDetailView(issue: issue)
                .environment(store)
                .frame(minWidth: 640, minHeight: 520)
        }
    }

    private var overview: some View {
        let blurb = tree?.overviewBlurb() ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: project.color))
                    .frame(width: 12, height: 12)
                Text(project.name)
                    .font(.title2.weight(.semibold))
                Text(project.key)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(StudioSection.overview.wash)
                    .clipShape(Capsule())
                Spacer()
                if store.productLibrary.isLoading(project) {
                    ProgressView()
                        .controlSize(.small)
                }
                if let repo = ProductLibrary.repoHint(for: project) {
                    Text(repo)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            if blurb.isEmpty {
                Text("A director pass will write the overview for this project.")
                    .foregroundStyle(.secondary)
            } else {
                MarkdownPreview(markdown: blurb, accent: StudioSection.overview.accent)
                    .lineLimit(4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(StudioSection.overview.wash)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ProjectTab.allCases) { item in
                    Button {
                        tab = item
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.section.symbol)
                            Text(item.title)
                        }
                        .font(.subheadline.weight(tab == item ? .semibold : .regular))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(tab == item ? item.section.accent.opacity(0.16) : Color.clear)
                        .foregroundStyle(tab == item ? item.section.accent : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var tabBody: some View {
        switch tab {
        case .design:
            docPane(
                files: tree?.files(matching: ["product/design"], names: ["design.md"]) ?? [],
                fallbackName: "design.md",
                emptyTitle: "Design is not written yet",
                emptyDetail: "A director pass will write it in this repo’s product/ folder."
            )
        case .architecture:
            docPane(
                files: tree?.files(matching: ["product/architecture"], names: ["architecture.md"]) ?? [],
                fallbackName: "architecture.md",
                emptyTitle: "Architecture is not written yet",
                emptyDetail: "A director pass will write the system design in product/."
            )
        case .mockups:
            mockupsPane
        case .decisions:
            decisionsPane
        case .issues:
            issuesPane
        case .timeline:
            PortfolioTimelineView(
                projectId: project.id,
                onSelectIssue: { issueId in
                    selectedIssue = store.issues.first(where: { $0.id == issueId })
                }
            )
        }
    }

    private func docPane(files: [ProductFile], fallbackName: String, emptyTitle: String, emptyDetail: String) -> some View {
        let markdown = files.first(where: { $0.name.lowercased() == fallbackName })?.markdown
            ?? files.first(where: { $0.isMarkdown })?.markdown
            ?? ""
        return DocumentPane(
            markdown: markdown,
            accent: tab.section.accent,
            imageResolver: { tree?.resolveImage($0) },
            emptyTitle: emptyTitle,
            emptyDetail: emptyDetail
        )
    }

    private var mockupsPane: some View {
        let files = tree?.files(matching: ["product/mockups"], names: ["mockups.md"]) ?? []
        let notes = files.filter(\.isMarkdown)
        let images = files.filter(\.isImage)
        return Group {
            if files.isEmpty {
                ContentUnavailableView {
                    Label("No mockups yet", systemImage: StudioSection.mockups.symbol)
                } description: {
                    Text("A director pass will drop frames in product/mockups/.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(notes) { file in
                            if let md = file.markdown {
                                MarkdownPreview(
                                    markdown: md,
                                    imageResolver: { tree?.resolveImage($0) },
                                    accent: StudioSection.mockups.accent
                                )
                            }
                        }
                        if !images.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                                ForEach(images) { file in
                                    VStack(alignment: .leading, spacing: 6) {
                                        if let img = file.nsImage {
                                            Image(nsImage: img)
                                                .resizable()
                                                .scaledToFit()
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        Text(file.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 920, alignment: .leading)
                }
            }
        }
    }

    private var decisionsPane: some View {
        let files = tree?.files(matching: ["product/decisions", "product/questions"], names: ["decisions.md", "questions.md"]) ?? []
        let markdown = files.first(where: { $0.name.lowercased() == "decisions.md" })?.markdown
            ?? files.first(where: { $0.isMarkdown })?.markdown
            ?? ""
        let notes = store.projectNotes(for: project.id)
        return VStack(spacing: 0) {
            DocumentPane(
                markdown: markdown,
                accent: StudioSection.decisions.accent,
                imageResolver: { tree?.resolveImage($0) },
                emptyTitle: "No decisions written yet",
                emptyDetail: "A director pass will lock calls in product/decisions.md."
            )
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("A note")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Add a short note…", text: $noteDraft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                    Button("Save") {
                        Task {
                            let body = noteDraft
                            do {
                                try await store.addProjectNote(projectId: project.id, body: body)
                                noteDraft = ""
                            } catch {
                                store.lastError = error.localizedDescription
                            }
                        }
                    }
                    .disabled(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !notes.isEmpty {
                    ForEach(notes.prefix(5)) { activity in
                        HStack(alignment: .top, spacing: 8) {
                            ActorAvatar(name: activity.actor, size: 20)
                            Text(activity.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(14)
            .background(StudioSection.decisions.wash)
        }
    }

    private var issuesPane: some View {
        let items = store.issues(inProject: project.id)
        return Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No issues", systemImage: "tray")
                } description: {
                    Text("Nothing filed for this project yet.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items) { issue in
                            Button {
                                selectedIssue = issue
                            } label: {
                                IssueRowView(issue: issue, showProject: false)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}
