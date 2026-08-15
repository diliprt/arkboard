import SwiftUI

struct IssueDetailColumn: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    @State private var comment = ""

    var issue: Issue? {
        store.selectedIssueID.flatMap { store.issue(idOrIdentifier: $0) }
    }

    var body: some View {
        Group {
            if let issue {
                detail(issue)
            } else {
                EmptyStateView(section: .issues, title: EmptyCopy.selectIssue.0, sentence: EmptyCopy.selectIssue.1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(StudioColor.wash(.teal, scheme: scheme))
            }
        }
    }

    private func detail(_ issue: Issue) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Archive") { store.archiveFromUI(issue) }
                    .font(type.caption)
            }
            .padding(.horizontal, Metrics.paneX)
            .padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(issue.identifier)
                        .font(type.mono)
                        .foregroundStyle(StudioColor.secondary)
                    Text(issue.title)
                        .font(type.display)
                    metadata(issue)
                    if issue.bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(EmptyCopy.noBody)
                            .font(type.callout)
                            .foregroundStyle(StudioColor.secondary)
                    } else {
                        MarkdownView(markdown: issue.bodyMarkdown, hue: .teal)
                    }
                    Text("Comments")
                        .font(type.heading)
                    let comments = store.comments(for: issue)
                    if comments.isEmpty {
                        Text(EmptyCopy.noComments)
                            .font(type.callout)
                            .foregroundStyle(StudioColor.secondary)
                    } else {
                        ForEach(comments) { row in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    ActorChip(name: row.author)
                                    Text(RelativeTime.format(row.createdAt))
                                        .font(type.caption)
                                        .foregroundStyle(StudioColor.secondary)
                                }
                                MarkdownView(markdown: row.bodyMarkdown, hue: Hue.actorHue(for: row.author))
                            }
                        }
                    }
                }
                .padding(Metrics.paneX)
                .frame(maxWidth: Metrics.proseMax, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(StudioColor.wash(.teal, scheme: scheme))
            HStack {
                TextField("Add a comment…", text: $comment, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(type.body)
                Button("Send") { post(issue) }
                    .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(12)
            .background(StudioColor.card)
        }
    }

    private func metadata(_ issue: Issue) -> some View {
        HStack(spacing: 8) {
            if let project = store.project(id: issue.projectId) {
                Chip(text: project.name, hue: .teal)
            }
            Text("filed \(RelativeTime.format(issue.createdAt))")
                .font(type.caption)
                .foregroundStyle(StudioColor.secondary)
            Text("updated \(RelativeTime.format(issue.updatedAt))")
                .font(type.caption)
                .foregroundStyle(StudioColor.secondary)
            ForEach(store.labels(for: issue), id: \.self) { name in
                Chip(text: name, hue: .slate)
            }
        }
    }

    private func post(_ issue: Issue) {
        let body = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        _ = try? store.addComment(idOrIdentifier: issue.id, body: body, actor: "Riyu")
        comment = ""
    }
}
