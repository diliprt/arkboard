import SwiftUI

struct MonitorView: View {
    @Environment(AppStore.self) private var store
    @State private var composerText = ""
    @State private var inspectorComment = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        HSplitView {
            mainColumn
                .frame(minWidth: 520, idealWidth: 720)
            inspector
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: store.composerFocusToken) { _, _ in
            composerFocused = true
        }
        .onAppear {
            if store.composerFocusToken > 0 {
                composerFocused = true
            }
        }
    }

    private var mainColumn: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    composer
                    reviewSection
                    featuresSection
                    bugsSection
                    compactWeekMap
                }
                .padding(20)
                .frame(maxWidth: 880, alignment: .leading)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monitor")
                .font(.title2.weight(.semibold))
            Text("What the bot team is doing — you steer, they execute")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ActorAvatar(name: "Riyu", size: 28)
            TextField("Tell the team…", text: $composerText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($composerFocused)
                .onSubmit { Task { await sendComposer() } }
            Button("Send") {
                Task { await sendComposer() }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help(store.expandedReviewIssueId == nil
                  ? "Post to the team activity feed"
                  : "Comment on the open review thread")
        }
    }

    private func sendComposer() async {
        let text = composerText
        do {
            _ = try await store.tellTheTeam(text)
            composerText = ""
        } catch {
            store.lastError = error.localizedDescription
        }
    }

    // MARK: - Needs you / Review

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Needs you / Review", count: store.needsReviewIssues.count, systemImage: "exclamationmark.bubble")
            if store.needsReviewIssues.isEmpty {
                emptyHint("Nothing waiting on you. Agents will surface a thread here when they need a steer.")
            } else {
                VStack(spacing: 8) {
                    ForEach(store.needsReviewIssues) { issue in
                        ReviewRow(issue: issue)
                    }
                }
            }
        }
    }

    // MARK: - Pending features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Pending features", count: store.pendingFeatures.count, systemImage: "list.number")
            Text("Drag to reorder. Agents take the top one next.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if store.pendingFeatures.isEmpty {
                emptyHint("No open features. Agents will add them here.")
            } else {
                List {
                    ForEach(store.pendingFeatures) { issue in
                        FeatureQueueRow(issue: issue)
                            .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectMonitorIssue(issue) }
                            .draggable(issue.id) {
                                FeatureQueueRow(issue: issue)
                                    .frame(width: 420)
                                    .opacity(0.9)
                            }
                            .dropDestination(for: String.self) { items, _ in
                                guard let id = items.first, id != issue.id else { return false }
                                Task {
                                    do {
                                        try await store.movePendingFeature(id, before: issue.id)
                                    } catch {
                                        store.lastError = error.localizedDescription
                                    }
                                }
                                return true
                            }
                    }
                    .onMove { source, dest in
                        Task {
                            do {
                                try await store.reorderPendingFeatures(from: source, to: dest)
                            } catch {
                                store.lastError = error.localizedDescription
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(store.pendingFeatures.count) * 56)
                .frame(maxHeight: CGFloat(min(store.pendingFeatures.count, 8)) * 64)
            }
        }
    }

    // MARK: - Bugs Now / Later

    private var bugsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Bugs", count: store.nowBugs.count + store.laterBugs.count, systemImage: "ant")
            Text("Drag between Now and Later. Order here is the steer — not a status menu.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                BugLaneColumn(title: "Now", later: false, issues: store.nowBugs)
                BugLaneColumn(title: "Later", later: true, issues: store.laterBugs)
            }
        }
    }

    // MARK: - Compact week map

    private var compactWeekMap: some View {
        let events = store.compactWeekEvents()
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("This fortnight", count: events.count, systemImage: "calendar")
            if events.isEmpty {
                emptyHint("No milestones or completions in the next two weeks.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(events) { event in
                            CompactWeekPill(event: event)
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Inspector

    private var inspector: some View {
        let project = store.resolveMonitorProject()
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if store.projects.count > 1 {
                Picker("Project", selection: Bindable(store).monitorProjectId) {
                    ForEach(store.projects) { p in
                        Text(p.name).tag(Optional(p.id))
                    }
                }
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let project {
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: project.color)).frame(width: 8, height: 8)
                            Text(project.name)
                                .font(.subheadline.weight(.semibold))
                            Text(project.key)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Docs")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            let docs = store.inspectorDocs(for: project)
                            if docs.isEmpty {
                                Text("No milestones yet for this project.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            } else {
                                ForEach(docs.prefix(8)) { ms in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ms.title)
                                            .font(.caption.weight(.medium))
                                        if !ms.description.isEmpty {
                                            Text(ms.description)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        Text(ms.targetDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Decisions")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            let decisions = store.inspectorDecisions(for: project)
                            if decisions.isEmpty {
                                Text("Comments on this project show up here.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            } else {
                                ForEach(decisions.prefix(10)) { comment in
                                    HStack(alignment: .top, spacing: 8) {
                                        ActorAvatar(name: comment.authorName, size: 20)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(comment.authorName)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(ActorStyle.color(for: comment.authorName))
                                            Text(comment.bodyMarkdown)
                                                .font(.caption)
                                                .lineLimit(3)
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Comment")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Note for this project…", text: $inspectorComment, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...5)
                            Button("Add comment") {
                                Task { await sendInspectorComment() }
                            }
                            .disabled(inspectorComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .controlSize(.small)
                        }
                    } else {
                        Text("Create a project to inspect docs and decisions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private func sendInspectorComment() async {
        let text = inspectorComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let issueId = store.expandedReviewIssueId ?? store.selectedIssueId,
           store.issues.contains(where: { $0.id == issueId && $0.deletedAt == nil }) {
            do {
                _ = try await store.addComment(issueId: issueId, body: text, authorName: "Riyu", actor: "Riyu")
                inspectorComment = ""
            } catch {
                store.lastError = error.localizedDescription
            }
            return
        }
        do {
            _ = try await store.tellTheTeam(text)
            inspectorComment = ""
        } catch {
            store.lastError = error.localizedDescription
        }
    }

    private func sectionTitle(_ title: String, count: Int, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
            Spacer()
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Rows

private struct ReviewRow: View {
    @Environment(AppStore.self) private var store
    let issue: Issue

    private var expanded: Bool { store.expandedReviewIssueId == issue.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    store.toggleReviewExpanded(issue)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        MonitorIssueIdentity(issue: issue)
                        Spacer(minLength: 8)
                        ActorStack(names: store.actors(for: issue))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button("Approve") {
                    Task {
                        do { try await store.approveReview(issueId: issue.id) }
                        catch { store.lastError = error.localizedDescription }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button("Later") {
                    Task {
                        do { try await store.deferReview(issueId: issue.id) }
                        catch { store.lastError = error.localizedDescription }
                    }
                }
                .controlSize(.small)
            }
            .padding(10)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    if !issue.descriptionMarkdown.isEmpty {
                        Text(issue.descriptionMarkdown)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    let thread = store.comments(for: issue)
                    if thread.isEmpty {
                        Text("No agent comments yet.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(thread) { comment in
                            HStack(alignment: .top, spacing: 8) {
                                ActorAvatar(name: comment.authorName, size: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(comment.authorName)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(ActorStyle.color(for: comment.authorName))
                                        Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Text(comment.bodyMarkdown)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                    Text("Reply from the composer above — it lands on this thread.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(store.selectedIssueId == issue.id ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.12))
        )
    }
}

private struct FeatureQueueRow: View {
    @Environment(AppStore.self) private var store
    let issue: Issue

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
            MonitorIssueIdentity(issue: issue)
            Spacer(minLength: 8)
            ActorStack(names: store.actors(for: issue))
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(store.selectedIssueId == issue.id ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.10))
        )
    }
}

private struct BugLaneColumn: View {
    @Environment(AppStore.self) private var store
    let title: String
    let later: Bool
    let issues: [Issue]
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(issues.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                if issues.isEmpty {
                    Text(later ? "Drop to defer" : "Drop to work now")
                        .font(.caption)
                        .foregroundStyle(targeted ? Color.accentColor : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                ForEach(issues) { issue in
                    HStack(spacing: 8) {
                        MonitorIssueIdentity(issue: issue)
                        Spacer(minLength: 4)
                        ActorStack(names: store.actors(for: issue), maxVisible: 2)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(store.selectedIssueId == issue.id ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.10))
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { store.selectMonitorIssue(issue) }
                    .draggable(issue.id) {
                        Text(issue.title)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .top)
            .padding(8)
            .background(targeted ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(targeted ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.12))
            )
            .dropDestination(for: String.self) { items, _ in
                guard let id = items.first else { return false }
                Task {
                    do {
                        try await store.setBugLater(id, later: later)
                        if let issue = store.issues.first(where: { $0.id == id }) {
                            store.selectMonitorIssue(issue)
                        }
                    } catch {
                        store.lastError = error.localizedDescription
                    }
                }
                return true
            } isTargeted: { value in
                targeted = value
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct MonitorIssueIdentity: View {
    @Environment(AppStore.self) private var store
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(issue.identifier)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                if let project = store.project(for: issue) {
                    Circle().fill(Color(hex: project.color)).frame(width: 6, height: 6)
                    Text(project.key)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Text(issue.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

private struct ActorStack: View {
    let names: [String]
    var maxVisible: Int = 3

    var body: some View {
        if names.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: -6) {
                ForEach(Array(names.prefix(maxVisible).enumerated()), id: \.offset) { _, name in
                    ActorAvatar(name: name, size: 20)
                }
                if names.count > maxVisible {
                    Text("+\(names.count - maxVisible)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 6)
                }
            }
            .accessibilityLabel(names.joined(separator: ", "))
        }
    }
}

private struct CompactWeekPill: View {
    let event: TimelineEvent

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: event.projectColor))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(event.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
        .help(event.subtitle)
    }
}
