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
                }

                TextField("Issue title", text: $title, axis: .vertical)
                    .font(.title2.weight(.semibold))
                    .textFieldStyle(.plain)
                    .onChange(of: title) { _, _ in
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
                        Task { try? await store.updateIssue(id: issue.id, status: newValue) }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(IssuePriority.allCases) { p in
                            Label(p.displayName, systemImage: p.symbolName).tag(p)
                        }
                    }
                    .frame(minWidth: 140, idealWidth: 160, maxWidth: 180)
                    .onChange(of: priority) { _, newValue in
                        Task { try? await store.updateIssue(id: issue.id, priority: newValue) }
                    }
                }

                LabeledContent("Assignee") {
                    TextField("Optional", text: $assignee)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .onSubmit {
                            Task {
                                try? await store.updateIssue(id: issue.id, assigneeName: .some(assignee.isEmpty ? nil : assignee))
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Labels")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LabelTokensField(tokens: $labelTokens, placeholder: "Add label, Return or comma") {
                        Task { try? await store.setIssueLabels(issueId: issue.id, labelNames: labelTokens) }
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
                        .onChange(of: description) { _, _ in
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
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(comment.authorName)
                                    .font(.subheadline.weight(.semibold))
                                Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(comment.bodyMarkdown)
                                .font(.body)
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
                                try? await store.addComment(issueId: issue.id, body: commentDraft)
                                commentDraft = ""
                            }
                        }
                        .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(issue.identifier)
        .onAppear { syncFromIssue(force: true) }
        .onChange(of: issue.id) { _, _ in syncFromIssue(force: true) }
        .onChange(of: issue.updatedAt) { _, _ in
            // External MCP/UI mutation — refresh unless the user has unsaved local edits
            syncFromIssue(force: false)
        }
        .onChange(of: store.dataRevision) { _, _ in
            syncFromIssue(force: false)
        }
    }

    private func syncFromIssue(force: Bool) {
        if !force, isDirty, lastSyncedUpdatedAt == issue.updatedAt {
            return
        }
        // If dirty and updatedAt changed (external write), prefer remote unless title/desc still matching draft intent
        if !force, isDirty {
            // Keep in-progress title/description drafts; still refresh discrete fields
            status = issue.status
            priority = issue.priority
            assignee = issue.assigneeName ?? ""
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
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            try? await store.updateIssue(id: id, title: t, description: d)
            await MainActor.run {
                isDirty = false
                lastSyncedUpdatedAt = store.issues.first(where: { $0.id == id })?.updatedAt
            }
        }
    }
}
