import SwiftUI

struct IssueDetailView: View {
    @Environment(AppStore.self) private var store
    let issue: Issue

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var status: IssueStatus = .backlog
    @State private var priority: IssuePriority = .none
    @State private var assignee: String = ""
    @State private var commentDraft: String = ""
    @State private var labelTokens: [String] = []
    @State private var saveTask: Task<Void, Never>?
    @State private var lastSyncedUpdatedAt: Date?
    @State private var isDirty = false
    @State private var saveState: SaveState = .idle
    @State private var confirmArchive = false
    @State private var showLinkGitHub = false
    @State private var showSetGitHubRepo = false
    @State private var confirmUnlinkGitHub = false
    @State private var githubLinkDraft = ""
    @State private var githubRepoDraft = ""
    @State private var githubBusy = false
    @State private var githubBusyLabel: String?
    @State private var editingDescription = false

    private enum SaveState: Equatable {
        case idle, saving, saved, failed
    }

    private var project: Project? {
        store.project(for: issue)
    }

    private var projectGitHubRepo: String? {
        GitHubIssueLink.normalizeRepo(project?.githubRepo)
    }

    private var linkedGitHubPrimaryLabel: String {
        let parsed = GitHubIssueLink.parseIssueURL(issue.githubIssueUrl)
        let repo = parsed.repo ?? projectGitHubRepo
        let number = issue.githubIssueNumber ?? parsed.number
        if let repo, let number {
            return "\(repo)#\(number)"
        }
        if let number {
            return "#\(number)"
        }
        return issue.githubIssueUrl ?? "Linked"
    }

    private var unlinkConfirmTitle: String {
        if let number = issue.githubIssueNumber {
            return "Unlink #\(number) from \(issue.identifier)?"
        }
        return "Unlink GitHub from \(issue.identifier)?"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(issue.identifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if let project {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Circle().fill(Color(hex: project.color)).frame(width: 8, height: 8)
                        Text(project.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    saveStatusLabel
                }

                TextField("Issue title", text: $title, axis: .vertical)
                    .font(.title2.weight(.semibold))
                    .textFieldStyle(.plain)
                    .onChange(of: title) { _, newValue in
                        guard newValue != issue.title else { return }
                        isDirty = true
                        scheduleSave()
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Labels")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LabelTokensField(tokens: $labelTokens, placeholder: "Add label, Return or comma") {
                        Task { await mutate { try await store.setIssueLabels(issueId: issue.id, labelNames: labelTokens) } }
                    }
                    .frame(maxWidth: 360)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Description")
                            .font(.headline)
                        Spacer()
                        Button(editingDescription ? "Preview" : "Edit") {
                            editingDescription.toggle()
                        }
                        .font(.caption)
                    }
                    if editingDescription {
                        TextEditor(text: $description)
                            .appBodyFont()
                            .frame(minHeight: 140)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                            .onChange(of: description) { _, newValue in
                                guard newValue != issue.descriptionMarkdown else { return }
                                isDirty = true
                                scheduleSave()
                            }
                    } else if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("No description yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        MarkdownPreview(markdown: description, accent: StudioSection.issues.accent)
                    }
                }

                Divider()

                githubSection

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Comments")
                        .font(.headline)

                    let comments = store.comments(for: issue)
                    if comments.isEmpty {
                        Text("No comments yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(comments) { comment in
                        HStack(alignment: .top, spacing: 10) {
                            ActorAvatar(name: comment.authorName, size: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(comment.authorName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(ActorStyle.color(for: comment.authorName))
                                    Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                MarkdownPreview(markdown: comment.bodyMarkdown, accent: ActorStyle.color(for: comment.authorName))
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    HStack(alignment: .top) {
                        TextField("Add a comment…", text: $commentDraft, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        Button("Comment") {
                            Task {
                                let body = commentDraft
                                await mutate {
                                    try await store.addComment(issueId: issue.id, body: body)
                                }
                                if store.lastError == nil {
                                    commentDraft = ""
                                }
                            }
                        }
                        .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(issue.identifier)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if issue.deletedAt != nil {
                    Button("Restore") {
                        Task {
                            await mutate { try await store.restoreIssue(issue.id) }
                        }
                    }
                } else {
                    Button("Archive", role: .destructive) {
                        confirmArchive = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Archive this issue?",
            isPresented: $confirmArchive,
            titleVisibility: .visible
        ) {
            Button("Archive", role: .destructive) {
                Task {
                    await mutate { try await store.deleteIssue(issue.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(issue.identifier) — \(issue.title) will be archived. You can undo for ~10s or restore from Archived.")
        }
        .confirmationDialog(
            unlinkConfirmTitle,
            isPresented: $confirmUnlinkGitHub,
            titleVisibility: .visible
        ) {
            Button("Unlink", role: .destructive) {
                Task {
                    await runGitHubBusy("Unlinking…") {
                        try await store.unlinkIssueGitHub(identifier: issue.identifier, actor: "Riyu")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Link GitHub issue", isPresented: $showLinkGitHub) {
            TextField(
                projectGitHubRepo == nil
                    ? "https://github.com/owner/repo/issues/1"
                    : "URL or #number",
                text: $githubLinkDraft
            )
            Button("Link") {
                Task {
                    await runGitHubBusy("Linking…") {
                        let draft = githubLinkDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        var number: Int? = nil
                        var url: String? = draft
                        if draft.hasPrefix("#"), let n = Int(draft.dropFirst()) {
                            number = n
                            url = nil
                        } else if let n = Int(draft) {
                            number = n
                            url = nil
                        }
                        try await store.linkIssueGitHub(
                            identifier: issue.identifier,
                            number: number,
                            url: url,
                            actor: "Riyu"
                        )
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let repo = projectGitHubRepo {
                Text("Paste a GitHub issue URL, or a number like #12 for \(repo).")
            } else {
                Text("Paste a full GitHub issue URL, or set a project GitHub repo first to link by number.")
            }
        }
        .alert(
            projectGitHubRepo == nil ? "Set project GitHub repo" : "Edit project GitHub repo",
            isPresented: $showSetGitHubRepo
        ) {
            TextField("owner/repo", text: $githubRepoDraft)
            Button("Save") {
                Task {
                    guard let project else { return }
                    await runGitHubBusy("Saving…") {
                        let draft = githubRepoDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        try await store.setProjectGitHubRepo(
                            projectId: project.id,
                            repo: draft.isEmpty ? nil : draft,
                            actor: "Riyu"
                        )
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Example: diliprt/arkboard. Leave blank and Save to clear.")
        }
        .onAppear { syncFromIssue(force: true) }
        .onChange(of: issue.id) { _, _ in syncFromIssue(force: true) }
        .onChange(of: issue.updatedAt) { _, _ in
            syncFromIssue(force: false)
        }
        .onChange(of: store.dataRevision) { _, _ in
            syncFromIssue(force: false)
        }
    }

    @ViewBuilder
    private var saveStatusLabel: some View {
        switch saveState {
        case .idle:
            EmptyView()
        case .saving:
            Text("Saving…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .saved:
            Text("Saved")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed:
            Text("Failed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
        }
    }

    private func syncFromIssue(force: Bool) {
        if !force, isDirty, lastSyncedUpdatedAt == issue.updatedAt {
            return
        }
        if !force, isDirty {
            status = issue.status
            priority = issue.priority
            labelTokens = store.labels(for: issue).map(\.name)
            lastSyncedUpdatedAt = issue.updatedAt
            return
        }
        title = issue.title
        description = issue.descriptionMarkdown
        status = issue.status
        priority = issue.priority
        assignee = issue.assigneeName ?? ""
        labelTokens = store.labels(for: issue).map(\.name)
        lastSyncedUpdatedAt = issue.updatedAt
        isDirty = false
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let id = issue.id
        let t = title
        let d = description
        saveState = .saving
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            do {
                try await store.updateIssue(
                    id: id,
                    title: t,
                    description: d
                )
                await MainActor.run {
                    isDirty = false
                    lastSyncedUpdatedAt = store.issues.first(where: { $0.id == id })?.updatedAt
                    saveState = .saved
                }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await MainActor.run {
                    if saveState == .saved { saveState = .idle }
                }
            } catch {
                await MainActor.run {
                    store.lastError = error.localizedDescription
                    saveState = .failed
                }
            }
        }
    }

    @ViewBuilder
    private var githubSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("GitHub")
                    .font(.headline)
                Spacer()
                if githubBusy {
                    ProgressView()
                        .controlSize(.small)
                    if let githubBusyLabel {
                        Text(githubBusyLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                if let repo = projectGitHubRepo {
                    Text(repo)
                        .font(.subheadline.monospaced())
                    Button("Edit…") {
                        githubRepoDraft = repo
                        showSetGitHubRepo = true
                    }
                    .disabled(githubBusy || issue.deletedAt != nil)
                    Button("Clear", role: .destructive) {
                        Task {
                            guard let project else { return }
                            await runGitHubBusy("Saving…") {
                                try await store.setProjectGitHubRepo(
                                    projectId: project.id,
                                    repo: nil,
                                    actor: "Riyu"
                                )
                            }
                        }
                    }
                    .disabled(githubBusy || issue.deletedAt != nil)
                } else {
                    Text("No project repo set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Set…") {
                        githubRepoDraft = ""
                        showSetGitHubRepo = true
                    }
                    .disabled(githubBusy || issue.deletedAt != nil || project == nil)
                }
            }

            if let url = issue.githubIssueUrl, !url.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    Link(destination: URL(string: url) ?? URL(string: "https://github.com")!) {
                        Text(linkedGitHubPrimaryLabel)
                            .font(.subheadline.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .help(url)
                    Text(url)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(url)
                    Spacer()
                    Button("Unlink") {
                        confirmUnlinkGitHub = true
                    }
                    .disabled(githubBusy)
                }
            } else {
                Text("Not linked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(issue.githubIssueUrl == nil ? "Link…" : "Change link…") {
                    githubLinkDraft = issue.githubIssueUrl ?? ""
                    showLinkGitHub = true
                }
                .disabled(githubBusy || issue.deletedAt != nil)

                Button("Create on GitHub") {
                    Task {
                        await runGitHubBusy("Creating…") {
                            try await store.createGitHubIssue(identifier: issue.identifier, actor: "Riyu")
                        }
                    }
                }
                .disabled(
                    githubBusy
                        || issue.deletedAt != nil
                        || issue.githubIssueUrl != nil
                        || projectGitHubRepo == nil
                )
            }

            if projectGitHubRepo == nil, issue.githubIssueUrl == nil, issue.deletedAt == nil {
                Text("Set a GitHub repo for this project first")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func runGitHubBusy(_ label: String, _ body: () async throws -> Void) async {
        githubBusy = true
        githubBusyLabel = label
        await mutate(body)
        githubBusy = false
        githubBusyLabel = nil
    }

    private func mutate(_ body: () async throws -> Void) async {
        do {
            try await body()
        } catch {
            store.lastError = error.localizedDescription
        }
    }
}
