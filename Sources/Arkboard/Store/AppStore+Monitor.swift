import Foundation
import GRDB

extension AppStore {
    var isMonitor: Bool {
        if case .monitor = selection { return true }
        return false
    }

    func focusComposer() {
        selection = .monitor
        composerFocusToken &+= 1
    }

    /// Open issues that need a human steer: @Riyu / review label, not approved or deferred.
    var needsReviewIssues: [Issue] {
        activeIssues.filter { issue in
            guard issue.status.isOpen else { return false }
            if hasLabel(issue, "approved") || hasLabel(issue, "later") { return false }
            if hasLabel(issue, "review") || hasLabel(issue, "needs-you") { return true }
            return isAddressedToRiyu(issue)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Open features. List order is the agent queue (top = next).
    var pendingFeatures: [Issue] {
        activeIssues.filter { issue in
            issue.status.isOpen && hasLabel(issue, "feature")
        }
        .sorted { lhs, rhs in
            if lhs.orderInStatus != rhs.orderInStatus {
                return lhs.orderInStatus < rhs.orderInStatus
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var nowBugs: [Issue] {
        openBugs.filter { !hasLabel($0, "later") }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var laterBugs: [Issue] {
        openBugs.filter { hasLabel($0, "later") }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var openBugs: [Issue] {
        activeIssues.filter { issue in
            issue.status.isOpen && hasLabel(issue, "bug")
        }
    }

    func hasLabel(_ issue: Issue, _ name: String) -> Bool {
        labels(for: issue).contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func isAddressedToRiyu(_ issue: Issue) -> Bool {
        let commentsHit = comments(for: issue).contains { comment in
            MentionParser.allMentions(in: comment.bodyMarkdown).contains {
                $0.caseInsensitiveCompare("Riyu") == .orderedSame
            }
        }
        if commentsHit { return true }
        return activities.contains { activity in
            activity.issueId == issue.id && activity.targetActors.contains {
                $0.caseInsensitiveCompare("Riyu") == .orderedSame
            }
        }
    }

    /// Distinct actors who have spoken or acted on this issue (for avatar stacks).
    func actors(for issue: Issue) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for comment in comments(for: issue) {
            let key = comment.authorName.lowercased()
            if seen.insert(key).inserted {
                result.append(comment.authorName)
            }
        }
        for activity in activities where activity.issueId == issue.id {
            let key = activity.actor.lowercased()
            if seen.insert(key).inserted {
                result.append(activity.actor)
            }
        }
        return result
    }

    func resolveMonitorProject() -> Project? {
        if let id = monitorProjectId, let project = projects.first(where: { $0.id == id }) {
            return project
        }
        if let issue = selectedIssue {
            return project(for: issue)
        }
        return projects.first
    }

    func selectMonitorIssue(_ issue: Issue) {
        selectedIssueId = issue.id
        monitorProjectId = issue.projectId
    }

    func toggleReviewExpanded(_ issue: Issue) {
        selectMonitorIssue(issue)
        if expandedReviewIssueId == issue.id {
            expandedReviewIssueId = nil
        } else {
            expandedReviewIssueId = issue.id
        }
    }

    /// Composer: comment on the expanded review thread, otherwise a workspace activity as Riyu.
    @discardableResult
    func tellTheTeam(_ message: String) async throws -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyComment }
        if let issueId = expandedReviewIssueId,
           issues.contains(where: { $0.id == issueId && $0.deletedAt == nil }) {
            _ = try await addComment(issueId: issueId, body: trimmed, authorName: "Riyu", actor: "Riyu")
            return true
        }
        try await dbWriteToldTeam(trimmed)
        try await reloadAll()
        return true
    }

    private func dbWriteToldTeam(_ message: String) async throws {
        let preview = message.count > 80 ? String(message.prefix(77)) + "…" : message
        let projectId = monitorProjectId ?? projects.first?.id
        try await writeActivity(
            actor: "Riyu",
            action: ActivityAction.told_team.rawValue,
            summary: "Riyu told the team: \(preview)",
            issueId: nil,
            projectId: projectId,
            kind: .comment
        )
    }

    /// Shared write for workspace-level activity (Monitor composer with no open thread).
    func writeActivity(
        actor: String,
        action: String,
        summary: String,
        issueId: String?,
        projectId: String?,
        kind: ActivityKind
    ) async throws {
        try await persistActivity(
            actor: actor,
            action: action,
            summary: summary,
            issueId: issueId,
            projectId: projectId,
            kind: kind
        )
    }

    func reorderPendingFeatures(from source: IndexSet, to destination: Int) async throws {
        var items = pendingFeatures
        items.move(fromOffsets: source, toOffset: destination)
        try await persistFeatureOrder(items)
    }

    func movePendingFeature(_ issueId: String, before beforeId: String?) async throws {
        var items = pendingFeatures.filter { $0.id != issueId }
        guard let moving = pendingFeatures.first(where: { $0.id == issueId }) else { return }
        if let beforeId, let idx = items.firstIndex(where: { $0.id == beforeId }) {
            items.insert(moving, at: idx)
        } else {
            items.append(moving)
        }
        try await persistFeatureOrder(items)
    }

    func setBugLater(_ issueId: String, later: Bool) async throws {
        try await toggleIssueLabel(issueId: issueId, name: "later", present: later, actor: "Riyu")
    }

    func approveReview(issueId: String) async throws {
        _ = try await addComment(issueId: issueId, body: "Approved — go ahead.", authorName: "Riyu", actor: "Riyu")
        try await toggleIssueLabel(issueId: issueId, name: "review", present: false, actor: "Riyu")
        try await toggleIssueLabel(issueId: issueId, name: "needs-you", present: false, actor: "Riyu")
        try await toggleIssueLabel(issueId: issueId, name: "later", present: false, actor: "Riyu")
        try await toggleIssueLabel(issueId: issueId, name: "approved", present: true, actor: "Riyu")
        if expandedReviewIssueId == issueId { expandedReviewIssueId = nil }
    }

    func deferReview(issueId: String) async throws {
        _ = try await addComment(issueId: issueId, body: "Later — not now.", authorName: "Riyu", actor: "Riyu")
        try await toggleIssueLabel(issueId: issueId, name: "review", present: false, actor: "Riyu")
        try await toggleIssueLabel(issueId: issueId, name: "needs-you", present: false, actor: "Riyu")
        try await toggleIssueLabel(issueId: issueId, name: "later", present: true, actor: "Riyu")
        if expandedReviewIssueId == issueId { expandedReviewIssueId = nil }
    }

    func toggleIssueLabel(issueId: String, name: String, present: Bool, actor: String = "Riyu") async throws {
        guard let issue = issues.first(where: { $0.id == issueId }) else { throw StoreError.notFound }
        var names = labels(for: issue).map(\.name)
        let exists = names.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        if present && !exists {
            names.append(name)
        } else if !present && exists {
            names.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        } else {
            return
        }
        try await setIssueLabels(issueId: issueId, labelNames: names, actor: actor)
    }

    func inspectorDocs(for project: Project) -> [Milestone] {
        milestones.filter { $0.projectId == project.id || $0.projectId == nil }
            .sorted { $0.targetDate < $1.targetDate }
    }

    func inspectorDecisions(for project: Project) -> [Comment] {
        let ids = Set(activeIssues.filter { $0.projectId == project.id }.map(\.id))
        return comments
            .filter { ids.contains($0.issueId) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func compactWeekEvents() -> [TimelineEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 14, to: start) ?? start
        return timelineEvents(mode: .plan).filter { $0.date >= start && $0.date < end }
    }
}

// MARK: - Persistence helpers used by Monitor (same DB pool as AppStore)

extension AppStore {
    /// Writes one activity row without going through comment insert.
    fileprivate func persistActivity(
        actor: String,
        action: String,
        summary: String,
        issueId: String?,
        projectId: String?,
        kind: ActivityKind
    ) async throws {
        try await performWrite { db in
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: action,
                summary: summary,
                issueId: issueId,
                projectId: projectId,
                kind: kind
            )
        }
    }

    fileprivate func persistFeatureOrder(_ items: [Issue]) async throws {
        try await performWrite { db in
            let now = Date()
            for (index, item) in items.enumerated() {
                guard var issue = try Issue.fetchOne(db, key: item.id) else { continue }
                issue.orderInStatus = Double(index)
                issue.updatedAt = now
                try issue.update(db)
            }
        }
        try await reloadAll()
    }
}
