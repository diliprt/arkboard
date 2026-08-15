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

    /// Design requirements in queue order (top = next).
    var monitorRequirements: [Requirement] {
        listRequirements()
    }

    var selectedRequirement: Requirement? {
        guard let selectedRequirementId else { return nil }
        return requirements.first { $0.id == selectedRequirementId }
    }

    /// Open non-bug issues — compact secondary list on Monitor.
    var compactOpenIssues: [Issue] {
        activeIssues.filter { issue in
            issue.status.isOpen && !hasLabel(issue, "bug")
        }
        .sorted { $0.updatedAt > $1.updatedAt }
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
        if let requirement = selectedRequirement {
            return project(for: requirement)
        }
        if let id = monitorProjectId, let project = projects.first(where: { $0.id == id }) {
            return project
        }
        if let issue = selectedIssue {
            return project(for: issue)
        }
        return projects.first
    }

    func selectMonitorRequirement(_ requirement: Requirement) {
        selectedRequirementId = requirement.id
        monitorProjectId = requirement.projectId
    }

    func toggleRequirementExpanded(_ requirement: Requirement) {
        selectMonitorRequirement(requirement)
        if expandedRequirementId == requirement.id {
            expandedRequirementId = nil
        } else {
            expandedRequirementId = requirement.id
        }
    }

    func selectMonitorIssue(_ issue: Issue) {
        selectedIssueId = issue.id
        monitorProjectId = issue.projectId
    }

    /// Composer: comment on the expanded requirement thread, otherwise workspace activity as Riyu.
    @discardableResult
    func tellTheTeam(_ message: String) async throws -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyComment }
        if let requirementId = expandedRequirementId,
           requirements.contains(where: { $0.id == requirementId }) {
            _ = try await addRequirementComment(requirementId: requirementId, body: trimmed, authorName: "Riyu", actor: "Riyu")
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
            requirementId: expandedRequirementId,
            kind: .comment
        )
    }

    func writeActivity(
        actor: String,
        action: String,
        summary: String,
        issueId: String?,
        projectId: String?,
        requirementId: String? = nil,
        kind: ActivityKind
    ) async throws {
        try await persistActivity(
            actor: actor,
            action: action,
            summary: summary,
            issueId: issueId,
            projectId: projectId,
            requirementId: requirementId,
            kind: kind
        )
    }

    func setBugLater(_ issueId: String, later: Bool) async throws {
        try await toggleIssueLabel(issueId: issueId, name: "later", present: later, actor: "Riyu")
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
}

extension AppStore {
    fileprivate func persistActivity(
        actor: String,
        action: String,
        summary: String,
        issueId: String?,
        projectId: String?,
        requirementId: String?,
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
                requirementId: requirementId,
                kind: kind
            )
        }
    }
}


extension AppStore {
    var notWorkingRequirements: [Requirement] {
        requirements.filter { $0.working == .not_working }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func issues(inProject projectId: String) -> [Issue] {
        activeIssues.filter { $0.projectId == projectId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func projectNotes(for projectId: String) -> [Activity] {
        activities.filter { activity in
            activity.projectId == projectId
                && activity.issueId == nil
                && activity.requirementId == nil
                && (activity.action == ActivityAction.commented.rawValue
                    || activity.action == ActivityAction.told_team.rawValue)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func addProjectNote(projectId: String, body: String) async throws {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyComment }
        let preview = trimmed.count > 80 ? String(trimmed.prefix(77)) + "…" : trimmed
        let key = projects.first(where: { $0.id == projectId })?.key ?? "project"
        try await writeActivity(
            actor: "Riyu",
            action: ActivityAction.commented.rawValue,
            summary: "Riyu noted on \(key): \(preview)",
            issueId: nil,
            projectId: projectId,
            kind: .comment
        )
        try await reloadAll()
    }
}
