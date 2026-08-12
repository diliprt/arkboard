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

    private enum SaveState: Equatable {
        case idle, saving, saved, failed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(issue.identifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if let project = store.project(for: issue) {
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

                HStack(spacing: 12) {
                    Picker("Status", selection: $status) {
                        ForEach(IssueStatus.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .frame(minWidth: 140, idealWidth: 160, maxWidth: 180)
                    .onChange(of: status) { _, newValue in
                        guard newValue != issue.status else { return }
                        Task { await mutate { try await store.updateIssue(id: issue.id, status: newValue) } }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(IssuePriority.allCases) { p in
                            Label(p.displayName, systemImage: p.symbolName).tag(p)
                        }
                    }
                    .frame(minWidth: 140, idealWidth: 160, maxWidth: 180)
                    .onChange(of: priority) { _, newValue in
                        guard newValue != issue.priority else { return }
                        Task { await mutate { try await store.updateIssue(id: issue.id, priority: newValue) } }
                    }
                }

                LabeledContent("Assignee") {
                    TextField("Optional", text: $assignee)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .onChange(of: assignee) { _, newValue in
                            let current = issue.assigneeName ?? ""
                            guard newValue != current else { return }
                            isDirty = true
                            scheduleSave()
                        }
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
                    Text("Description")
                        .font(.headline)
                    TextEditor(text: $description)
                        .font(.body)
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
                }

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
                                Text(comment.bodyMarkdown)
                                    .font(.body)
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
                        Task {
                            await mutate { try await store.deleteIssue(issue.id) }
                        }
                    }
                }
            }
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
        let a = assignee
        saveState = .saving
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            do {
                try await store.updateIssue(
                    id: id,
                    title: t,
                    description: d,
                    assigneeName: .some(a.isEmpty ? nil : a)
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

    private func mutate(_ body: () async throws -> Void) async {
        do {
            try await body()
        } catch {
            store.lastError = error.localizedDescription
        }
    }
}
