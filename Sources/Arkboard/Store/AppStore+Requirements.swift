import Foundation
import GRDB

extension AppStore {
    func project(for requirement: Requirement) -> Project? {
        projects.first { $0.id == requirement.projectId }
    }

    func comments(for requirement: Requirement) -> [RequirementComment] {
        requirementComments
            .filter { $0.requirementId == requirement.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func requirement(forActivity activity: Activity) -> Requirement? {
        guard let id = activity.requirementId else { return nil }
        return requirements.first { $0.id == id }
    }

    func actors(for requirement: Requirement) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for comment in comments(for: requirement) {
            let key = comment.authorName.lowercased()
            if seen.insert(key).inserted {
                result.append(comment.authorName)
            }
        }
        for activity in activities where activity.requirementId == requirement.id {
            let key = activity.actor.lowercased()
            if seen.insert(key).inserted {
                result.append(activity.actor)
            }
        }
        return result
    }

    func listRequirements(projectKey: String? = nil) -> [Requirement] {
        var items = requirements
        if let projectKey,
           let p = projects.first(where: { $0.key.caseInsensitiveCompare(projectKey) == .orderedSame }) {
            items = items.filter { $0.projectId == p.id }
        }
        return items.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }

    func requirementDictionary(_ requirement: Requirement) -> [String: Any] {
        [
            "id": requirement.id,
            "identifier": requirement.identifier,
            "projectId": requirement.projectId,
            "projectKey": project(for: requirement)?.key ?? "",
            "title": requirement.title,
            "body": requirement.bodyMarkdown,
            "implementing": requirement.implementing.rawValue,
            "working": requirement.working.rawValue,
            "sortOrder": requirement.sortOrder,
            "linkedIssueIdentifiers": requirement.linkedIdentifiers,
            "createdAt": ISO8601DateFormatter().string(from: requirement.createdAt),
            "updatedAt": ISO8601DateFormatter().string(from: requirement.updatedAt),
        ]
    }

    func requirementThread(idOrIdentifier: String) -> (requirement: Requirement, comments: [RequirementComment], activities: [Activity])? {
        guard let requirement = requirements.first(where: {
            $0.id == idOrIdentifier || $0.identifier.caseInsensitiveCompare(idOrIdentifier) == .orderedSame
        }) else { return nil }
        let threadComments = comments(for: requirement)
        let threadActivity = activities
            .filter { $0.requirementId == requirement.id }
            .sorted { $0.createdAt < $1.createdAt }
        return (requirement, threadComments, threadActivity)
    }

    @discardableResult
    func createRequirement(
        projectId: String? = nil,
        projectKey: String? = nil,
        title: String,
        body: String = "",
        implementing: RequirementImplementing = .not_started,
        working: RequirementWorking = .unknown,
        sortOrder: Double? = nil,
        linkedIssueIdentifiers: [String] = [],
        actor: String = "Riyu"
    ) async throws -> Requirement {
        let trimmed = Self.normalizeTitle(title)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }

        var pid = projectId
        if pid == nil, let projectKey,
           let p = projects.first(where: { $0.key.caseInsensitiveCompare(projectKey) == .orderedSame }) {
            pid = p.id
        }
        pid = pid ?? selectedProjectId ?? monitorProjectId ?? projects.first?.id
        guard let pid, projects.contains(where: { $0.id == pid }) else {
            throw StoreError.noProject
        }

        let created = try await performWriteValue { db -> Requirement in
            guard var project = try Project.fetchOne(db, key: pid) else {
                throw StoreError.noProject
            }
            project.requirementCounter += 1
            let maxOrder = try Double.fetchOne(
                db,
                sql: "SELECT MAX(sortOrder) FROM requirement WHERE projectId = ?",
                arguments: [pid]
            ) ?? -1
            let now = Date()
            let requirement = Requirement(
                id: UUID().uuidString,
                identifier: "\(project.key)-R\(project.requirementCounter)",
                projectId: pid,
                title: trimmed,
                bodyMarkdown: body,
                implementing: implementing,
                working: working,
                sortOrder: sortOrder ?? (maxOrder + 1),
                createdAt: now,
                updatedAt: now,
                linkedIssueIdentifiers: Requirement.encodeIdentifiers(linkedIssueIdentifiers)
            )
            try project.update(db)
            try requirement.insert(db)
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.created_requirement.rawValue,
                summary: "\(actor) created requirement \(requirement.identifier): \(requirement.title)",
                projectId: pid,
                requirementId: requirement.id,
                kind: .system
            )
            return requirement
        }
        try await reloadAll()
        selectedRequirementId = created.id
        return requirements.first(where: { $0.id == created.id }) ?? created
    }

    @discardableResult
    func updateRequirement(
        id: String? = nil,
        identifier: String? = nil,
        title: String? = nil,
        body: String? = nil,
        implementing: RequirementImplementing? = nil,
        working: RequirementWorking? = nil,
        sortOrder: Double? = nil,
        linkedIssueIdentifiers: [String]? = nil,
        actor: String = "Riyu"
    ) async throws -> Requirement {
        let key = (id?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? (identifier?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        guard let key else { throw StoreError.notFound }

        let updated = try await performWriteValue { db -> Requirement in
            guard var requirement = try Self.fetchRequirement(db, key: key) else {
                throw StoreError.notFound
            }
            var changes: [String] = []
            if let title {
                let t = Self.normalizeTitle(title)
                guard !t.isEmpty else { throw StoreError.emptyTitle }
                if t != requirement.title {
                    requirement.title = t
                    changes.append("title")
                }
            }
            if let body, body != requirement.bodyMarkdown {
                requirement.bodyMarkdown = body
                changes.append("body")
            }
            if let implementing, implementing != requirement.implementing {
                requirement.implementing = implementing
                changes.append("implementing → \(implementing.rawValue)")
            }
            if let working, working != requirement.working {
                requirement.working = working
                changes.append("working → \(working.rawValue)")
            }
            if let sortOrder {
                requirement.sortOrder = sortOrder
            }
            if let linkedIssueIdentifiers {
                requirement.linkedIssueIdentifiers = Requirement.encodeIdentifiers(linkedIssueIdentifiers)
                changes.append("linkedIssues")
            }
            requirement.updatedAt = Date()
            try requirement.update(db)
            if !changes.isEmpty {
                try ActivityLogger.insert(
                    db,
                    actor: actor,
                    action: ActivityAction.updated_requirement.rawValue,
                    summary: "\(actor) updated \(requirement.identifier) (\(changes.joined(separator: ", ")))",
                    projectId: requirement.projectId,
                    requirementId: requirement.id,
                    kind: .system
                )
            }
            return requirement
        }
        try await reloadAll()
        return requirements.first(where: { $0.id == updated.id }) ?? updated
    }

    @discardableResult
    func addRequirementComment(
        requirementId: String,
        body: String,
        authorName: String = "Riyu",
        actor: String? = nil
    ) async throws -> RequirementComment {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyComment }
        let author = (actor ?? authorName).trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAuthor = author.isEmpty ? "Agent" : author
        let targets = MentionParser.allMentions(in: trimmed)
        let comment = RequirementComment(
            id: UUID().uuidString,
            requirementId: requirementId,
            bodyMarkdown: trimmed,
            authorName: resolvedAuthor,
            createdAt: Date()
        )
        try await performWriteValue { db in
            guard var requirement = try Requirement.fetchOne(db, key: requirementId) else {
                throw StoreError.notFound
            }
            try comment.insert(db)
            requirement.updatedAt = Date()
            try requirement.update(db)
            let preview = trimmed.count > 80 ? String(trimmed.prefix(77)) + "…" : trimmed
            let encodedTargets = Activity.encodeTargets(targets)
            let kind = MentionParser.inferKind(body: trimmed, targetActor: encodedTargets)
            let arrow = targets.isEmpty ? "" : " → \(targets.joined(separator: ", "))"
            try ActivityLogger.insert(
                db,
                actor: resolvedAuthor,
                action: ActivityAction.commented.rawValue,
                summary: "\(resolvedAuthor)\(arrow) on \(requirement.identifier): \(preview)",
                projectId: requirement.projectId,
                requirementId: requirement.id,
                targetActor: encodedTargets,
                kind: kind
            )
        }
        try await reloadAll()
        return comment
    }

    func cycleImplementing(_ id: String, actor: String = "Riyu") async throws {
        guard let requirement = requirements.first(where: { $0.id == id }) else { throw StoreError.notFound }
        _ = try await updateRequirement(id: id, implementing: requirement.implementing.next, actor: actor)
    }

    func cycleWorking(_ id: String, actor: String = "Riyu") async throws {
        guard let requirement = requirements.first(where: { $0.id == id }) else { throw StoreError.notFound }
        _ = try await updateRequirement(id: id, working: requirement.working.next, actor: actor)
    }

    func moveRequirement(_ requirementId: String, before beforeId: String?) async throws {
        var items = listRequirements().filter { $0.id != requirementId }
        guard let moving = listRequirements().first(where: { $0.id == requirementId }) else { return }
        if let beforeId, let idx = items.firstIndex(where: { $0.id == beforeId }) {
            items.insert(moving, at: idx)
        } else {
            items.append(moving)
        }
        try await persistRequirementOrder(items)
    }

    private func persistRequirementOrder(_ items: [Requirement]) async throws {
        try await performWrite { db in
            let now = Date()
            for (index, item) in items.enumerated() {
                guard var requirement = try Requirement.fetchOne(db, key: item.id) else { continue }
                requirement.sortOrder = Double(index)
                requirement.updatedAt = now
                try requirement.update(db)
            }
        }
        try await reloadAll()
    }

    nonisolated private static func fetchRequirement(_ db: Database, key: String) throws -> Requirement? {
        if let byId = try Requirement.fetchOne(db, key: key) { return byId }
        return try Requirement
            .filter(sql: "LOWER(identifier) = LOWER(?)", arguments: [key])
            .fetchOne(db)
    }
}
