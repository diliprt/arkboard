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
            projectPane
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
                    requirementsSection
                    issuesAndBugsSection
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
            Text("Design requirements — you steer, they execute")
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
            .help(store.expandedRequirementId == nil
                  ? "Post to the team activity feed"
                  : "Comment on the open requirement thread")
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

    // MARK: - Requirements (center)

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Requirements", count: store.monitorRequirements.count, systemImage: "checkmark.seal")
            Text("Drag to reorder. Tap implementing / working to steer. Expand a row for the agent thread.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if store.monitorRequirements.isEmpty {
                emptyHint("No design requirements yet. Agents add them via MCP (create_requirement).")
            } else {
                RequirementDropLane(requirements: store.monitorRequirements)
            }
        }
    }

    // MARK: - Issues + bugs (secondary)

    private var issuesAndBugsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(
                "Issues & bugs",
                count: store.compactOpenIssues.count + store.nowBugs.count + store.laterBugs.count,
                systemImage: "tray"
            )
            Text("Secondary. Inbox still has the full issue list.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !store.compactOpenIssues.isEmpty {
                VStack(spacing: 6) {
                    ForEach(store.compactOpenIssues.prefix(6)) { issue in
                        CompactIssueRow(issue: issue)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                BugLaneColumn(title: "Bugs · Now", later: false, issues: store.nowBugs)
                BugLaneColumn(title: "Bugs · Later", later: true, issues: store.laterBugs)
            }
        }
    }

    // MARK: - This project

    private var projectPane: some View {
        let project = store.resolveMonitorProject()
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("This project")
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

                        if let requirement = store.selectedRequirement {
                            selectedRequirementCard(requirement)
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
                            Text("Note")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Note for this project…", text: $inspectorComment, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...5)
                            Button("Add note") {
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

    private func selectedRequirementCard(_ requirement: Requirement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected requirement")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(requirement.identifier)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(requirement.title)
                .font(.subheadline.weight(.semibold))
            if !requirement.bodyMarkdown.isEmpty {
                Text(requirement.bodyMarkdown)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                HealthChip(title: requirement.implementing.displayName, hex: requirement.implementing.tintHex)
                HealthChip(title: requirement.working.displayName, hex: requirement.working.tintHex)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sendInspectorComment() async {
        let text = inspectorComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let requirementId = store.expandedRequirementId ?? store.selectedRequirementId,
           store.requirements.contains(where: { $0.id == requirementId }) {
            do {
                _ = try await store.addRequirementComment(requirementId: requirementId, body: text, authorName: "Riyu", actor: "Riyu")
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

// MARK: - Requirement drop-lane (no nested List)

private struct RequirementDropLane: View {
    @Environment(AppStore.self) private var store
    let requirements: [Requirement]
    @State private var endTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(requirements) { requirement in
                RequirementRow(requirement: requirement)
                    .draggable(requirement.id) {
                        RequirementDragPreview(requirement: requirement)
                            .frame(width: 420)
                            .opacity(0.9)
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let id = items.first, id != requirement.id else { return false }
                        Task {
                            do {
                                try await store.moveRequirement(id, before: requirement.id)
                            } catch {
                                store.lastError = error.localizedDescription
                            }
                        }
                        return true
                    }
            }

            Text("Drop here to move to end")
                .font(.caption)
                .foregroundStyle(endTargeted ? Color.accentColor : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(endTargeted ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .dropDestination(for: String.self) { items, _ in
                    guard let id = items.first else { return false }
                    Task {
                        do {
                            try await store.moveRequirement(id, before: nil)
                        } catch {
                            store.lastError = error.localizedDescription
                        }
                    }
                    return true
                } isTargeted: { value in
                    endTargeted = value
                }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.12))
        )
    }
}

private struct RequirementRow: View {
    @Environment(AppStore.self) private var store
    let requirement: Requirement
    @State private var threadReply = ""

    private var expanded: Bool { store.expandedRequirementId == requirement.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    store.toggleRequirementExpanded(requirement)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(requirement.identifier)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                if let project = store.project(for: requirement) {
                                    Circle().fill(Color(hex: project.color)).frame(width: 6, height: 6)
                                    Text(project.key)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(requirement.title)
                                .font(.subheadline.weight(.medium))
                                .multilineTextAlignment(.leading)
                            if !requirement.bodyMarkdown.isEmpty {
                                Text(requirement.bodyMarkdown)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .trailing, spacing: 6) {
                    Button {
                        Task {
                            do { try await store.cycleImplementing(requirement.id) }
                            catch { store.lastError = error.localizedDescription }
                        }
                    } label: {
                        HealthChip(title: requirement.implementing.displayName, hex: requirement.implementing.tintHex)
                    }
                    .buttonStyle(.plain)
                    .help("Cycle implementing: not started → implementing → implemented")

                    Button {
                        Task {
                            do { try await store.cycleWorking(requirement.id) }
                            catch { store.lastError = error.localizedDescription }
                        }
                    } label: {
                        HealthChip(title: requirement.working.displayName, hex: requirement.working.tintHex)
                    }
                    .buttonStyle(.plain)
                    .help("Cycle working: unknown → working → not working")

                    ActorStack(names: store.actors(for: requirement), maxVisible: 2)
                }
            }
            .padding(10)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    let thread = store.comments(for: requirement)
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

                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("Reply on this requirement…", text: $threadReply, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...4)
                            .onSubmit { Task { await sendThreadReply() } }
                        Button("Reply") {
                            Task { await sendThreadReply() }
                        }
                        .controlSize(.small)
                        .disabled(threadReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(store.selectedRequirementId == requirement.id ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.12))
        )
        .onTapGesture {
            store.selectMonitorRequirement(requirement)
        }
    }

    private func sendThreadReply() async {
        let text = threadReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            _ = try await store.addRequirementComment(requirementId: requirement.id, body: text, authorName: "Riyu", actor: "Riyu")
            threadReply = ""
        } catch {
            store.lastError = error.localizedDescription
        }
    }
}

private struct RequirementDragPreview: View {
    let requirement: Requirement

    var body: some View {
        HStack {
            Text(requirement.identifier)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(requirement.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct HealthChip: View {
    let title: String
    let hex: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(hex: hex))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(hex: hex).opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct CompactIssueRow: View {
    @Environment(AppStore.self) private var store
    let issue: Issue

    var body: some View {
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
                        .frame(maxWidth: .infinity, minHeight: 44)
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
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .top)
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
