import Foundation
import GRDB
import Observation

@MainActor
@Observable
final class AppStore {
    var workspace: Workspace?
    var projects: [Project] = []
    var issues: [Issue] = []
    var comments: [Comment] = []
    var milestones: [Milestone] = []
    var capabilities: [Capability] = []
    var activities: [Activity] = []
    var labels: [Label] = []
    var issueLabels: [IssueLabel] = []

    var serverState: ServerListenState = .offline(reason: "Starting")
    var documentBundles: [String: DocumentBundle] = [:]
    var focusComposer: Int = 0
    var focusIssueSearch: Int = 0
    var selectedIssueID: String?
    var undoArchive: UndoArchive?
    var sidebarSelection: SidebarItem {
        didSet { UserDefaults.standard.set(sidebarSelection.persistenceValue, forKey: SettingsKey.sidebarSelection) }
    }

    var appearance: AppearancePreference {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: SettingsKey.appearance) }
    }
    var fontSize: Int {
        didSet { UserDefaults.standard.set(fontSize, forKey: SettingsKey.fontSize) }
    }
    var fontFamily: FontFamilyID {
        didSet { UserDefaults.standard.set(fontFamily.rawValue, forKey: SettingsKey.fontFamily) }
    }

    let pool: DatabasePool
    let documents = DocumentLibrary()
    private var observers: [AnyDatabaseCancellable] = []
    private var server: StudioServer?

    init(pool: DatabasePool = AppDatabase.shared) {
        self.pool = pool
        let defaults = UserDefaults.standard
        let size = defaults.object(forKey: SettingsKey.fontSize) as? Int ?? 13
        fontSize = [12, 13, 14, 16].contains(size) ? size : 13
        fontFamily = FontFamilyID(rawValue: defaults.string(forKey: SettingsKey.fontFamily) ?? "system") ?? .system
        appearance = AppearancePreference(rawValue: defaults.string(forKey: SettingsKey.appearance) ?? "light") ?? .light
        sidebarSelection = .from(persistence: defaults.string(forKey: SettingsKey.sidebarSelection) ?? "monitor")
    }

    func start() async {
        do {
            try pool.write { db in
                try Seed.runIfEmpty(db)
            }
        } catch {
            NSLog("Arkboard seed failed: \(error)")
        }
        startObservations()
        await refreshAllDocuments()
        startServer()
    }

    func becomeActive() async {
        await refreshAllDocuments()
    }

    // MARK: - Observations

    private func startObservations() {
        observe(Workspace.all()) { [weak self] in self?.workspace = $0.first }
        observe(Project.order(Column("sortOrder"), Column("name"))) { [weak self] in self?.projects = $0 }
        observe(Issue.order(Column("updatedAt").desc)) { [weak self] in self?.issues = $0 }
        observe(Comment.order(Column("createdAt"))) { [weak self] in self?.comments = $0 }
        observe(Milestone.order(Column("targetDate"))) { [weak self] in self?.milestones = $0 }
        observe(Capability.order(Column("sortOrder"), Column("createdAt"))) { [weak self] in self?.capabilities = $0 }
        observe(Activity.order(Column("createdAt").desc)) { [weak self] in self?.activities = $0 }
        observe(Label.order(Column("name"))) { [weak self] in self?.labels = $0 }
        observe(IssueLabel.all()) { [weak self] in self?.issueLabels = $0 }
    }

    private func observe<T: FetchableRecord & TableRecord>(_ request: QueryInterfaceRequest<T>, assign: @escaping ([T]) -> Void) {
        let observation = ValueObservation.tracking { db in
            try request.fetchAll(db)
        }
        let cancellable = observation.start(in: pool, scheduling: .immediate, onError: { error in
            NSLog("Arkboard observation failed: \(error)")
        }, onChange: { rows in
            Task { @MainActor in
                assign(rows)
            }
        })
        observers.append(cancellable)
    }

    // MARK: - Mutate

    @discardableResult
    func mutate<T>(actor: String, _ body: (Database) throws -> (value: T, log: ActivityDraft?)) throws -> T {
        let who = Validation.actor(actor)
        return try pool.write { db in
            let result = try body(db)
            if let log = result.log {
                let row = Activity(
                    id: UUID().uuidString,
                    createdAt: Date(),
                    actor: who,
                    kind: log.kind,
                    action: log.action,
                    body: log.body,
                    targetActors: Activity.encodeTargets(log.targetActors),
                    projectId: log.projectId,
                    issueId: log.issueId,
                    capabilityId: log.capabilityId,
                    milestoneId: log.milestoneId
                )
                try row.insert(db)
            }
            return result.value
        }
    }

    // MARK: - Lookups

    func project(id: String) -> Project? { projects.first { $0.id == id } }
    func project(key: String) -> Project? { projects.first { $0.key.caseInsensitiveCompare(key) == .orderedSame } }
    func issue(idOrIdentifier value: String) -> Issue? {
        issues.first { $0.id == value || $0.identifier == value }
    }
    func capability(idOrIdentifier value: String) -> Capability? {
        capabilities.first { $0.id == value || $0.identifier == value }
    }
    func labels(for issue: Issue) -> [String] {
        let ids = Set(issueLabels.filter { $0.issueId == issue.id }.map(\.labelId))
        return labels.filter { ids.contains($0.id) }.map(\.name).sorted()
    }
    func comments(for issue: Issue) -> [Comment] {
        comments.filter { $0.issueId == issue.id }
    }
    func openIssueCount(for project: Project) -> Int {
        issues.filter { $0.projectId == project.id && $0.archivedAt == nil && $0.status != .done && $0.status != .canceled }.count
    }

    func humanIssues(projectId: String? = nil, query: String = "", includeArchived: Bool = false) -> [HumanIssueGroup: [Issue]] {
        let doneCutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        var filtered = issues.filter { issue in
            if let projectId, issue.projectId != projectId { return false }
            if !query.isEmpty {
                let hay = (issue.identifier + " " + issue.title + " " + issue.bodyMarkdown).lowercased()
                if !hay.contains(query.lowercased()) { return false }
            }
            return true
        }
        var grouped: [HumanIssueGroup: [Issue]] = [:]
        for issue in filtered {
            guard let group = HumanIssueGroup.group(for: issue) else { continue }
            if group == .archived && !includeArchived { continue }
            if group == .done, let completed = issue.completedAt, completed < doneCutoff { continue }
            if group == .done, issue.completedAt == nil { continue }
            grouped[group, default: []].append(issue)
        }
        return grouped
    }

    var brokenCapabilities: [Capability] {
        capabilities.filter { $0.health == .notWorking }.sorted { ($0.checkedAt ?? .distantPast) > ($1.checkedAt ?? .distantPast) }
    }

    var openQuestions: [OpenQuestion] {
        var result: [OpenQuestion] = []
        for project in projects {
            guard let bundle = documentBundles[project.id] else { continue }
            for document in bundle.documents where document.tab == .decisions {
                guard let markdown = document.markdown else { continue }
                for question in QuestionParser.openQuestions(in: markdown) {
                    result.append(
                        OpenQuestion(
                            projectId: project.id,
                            projectKey: project.key,
                            projectName: project.name,
                            projectColor: project.color,
                            path: document.path,
                            heading: question.heading,
                            anchor: question.anchor,
                            body: question.body
                        )
                    )
                }
            }
        }
        return result
    }

    // MARK: - Documents

    func refreshAllDocuments() async {
        var next: [String: DocumentBundle] = [:]
        for project in projects {
            next[project.id] = await documents.refresh(project: project)
        }
        documentBundles = next
    }

    func refreshDocuments(projectId: String) async {
        guard let project = project(id: projectId) else { return }
        documentBundles[projectId] = await documents.refresh(project: project)
    }

    func updateRepoPath(projectId: String, path: String?) throws {
        _ = try mutate(actor: "Riyu") { db in
            guard var project = try Project.fetchOne(db, key: projectId) else { throw ValidationError.missingProject }
            project.repoPath = path
            try project.update(db)
            return (project, nil)
        }
    }

    // MARK: - Projects

    func createProject(key: String, name: String, color: String?, summary: String?, repoPath: String?, githubRepo: String?, actor: String) throws -> Project {
        let key = try Validation.projectKey(key)
        let name = try Validation.collapseTitle(name)
        return try mutate(actor: actor) { db in
            if try Project.filter(Column("key") == key).fetchOne(db) != nil {
                throw ValidationError.duplicateKey(key)
            }
            let now = Date()
            let project = Project(
                id: UUID().uuidString,
                key: key,
                name: name,
                color: color?.isEmpty == false ? color! : "#5A62D6",
                summary: summary ?? "",
                repoPath: repoPath,
                githubRepo: githubRepo,
                issueCounter: 0,
                capabilityCounter: 0,
                sortOrder: Double(try Project.fetchCount(db)),
                createdAt: now
            )
            try project.insert(db)
            return (project, ActivityDraft(kind: .system, action: .createdProject, body: "Created project \(key)", projectId: project.id))
        }
    }

    // MARK: - Issues

    func createIssue(projectKey: String?, projectId: String?, title: String, body: String, status: String, priority: String, labels: [String], assignee: String?, actor: String) throws -> Issue {
        let title = try Validation.collapseTitle(title)
        let status = try Validation.issueStatus(status)
        let priority = try Validation.issuePriority(priority)
        let names = Validation.labels(labels)
        return try mutate(actor: actor) { db in
            var project = try Self.requireProject(db, key: projectKey, id: projectId)
            project.issueCounter += 1
            try project.update(db)
            let now = Date()
            let issue = Issue(
                id: UUID().uuidString,
                identifier: "\(project.key)-\(project.issueCounter)",
                projectId: project.id,
                title: title,
                bodyMarkdown: body,
                status: status,
                priority: priority,
                assignee: assignee?.isEmpty == true ? nil : assignee,
                sortOrder: 0,
                createdAt: now,
                updatedAt: now,
                completedAt: status == .done ? now : nil,
                archivedAt: nil
            )
            try issue.insert(db)
            try Self.replaceLabels(db, issueId: issue.id, names: names)
            return (issue, ActivityDraft(kind: .system, action: .createdIssue, body: "Filed \(issue.identifier): \(title)", projectId: project.id, issueId: issue.id))
        }
    }

    func updateIssue(idOrIdentifier: String, title: String?, body: String?, status: String?, priority: String?, labels: [String]?, assignee: String?, actor: String) throws -> Issue {
        if let status { _ = try Validation.issueStatus(status) }
        if let priority { _ = try Validation.issuePriority(priority) }
        let title = try title.map { try Validation.collapseTitle($0) }
        return try mutate(actor: actor) { db in
            guard var issue = try Self.fetchIssue(db, idOrIdentifier) else { throw ValidationError.missingIssue }
            var changes: [String] = []
            if let title, title != issue.title {
                issue.title = title
                changes.append("title")
            }
            if let body, body != issue.bodyMarkdown {
                issue.bodyMarkdown = body
                changes.append("body")
            }
            if let status {
                let parsed = try Validation.issueStatus(status)
                if parsed != issue.status {
                    issue.status = parsed
                    if parsed == .done {
                        issue.completedAt = Date()
                    } else {
                        issue.completedAt = nil
                    }
                    changes.append("status")
                }
            }
            if let priority {
                let parsed = try Validation.issuePriority(priority)
                if parsed != issue.priority {
                    issue.priority = parsed
                    changes.append("priority")
                }
            }
            if let assignee {
                issue.assignee = assignee.isEmpty ? nil : assignee
                changes.append("assignee")
            }
            if let labels {
                try Self.replaceLabels(db, issueId: issue.id, names: Validation.labels(labels))
                changes.append("labels")
            }
            issue.updatedAt = Date()
            try issue.update(db)
            let summary = changes.isEmpty ? "Updated \(issue.identifier)" : "Updated \(issue.identifier) (\(changes.joined(separator: ", ")))"
            return (issue, ActivityDraft(kind: .system, action: .updatedIssue, body: summary, projectId: issue.projectId, issueId: issue.id))
        }
    }

    func archiveIssue(idOrIdentifier: String, actor: String) throws -> Issue {
        try mutate(actor: actor) { db in
            guard var issue = try Self.fetchIssue(db, idOrIdentifier) else { throw ValidationError.missingIssue }
            issue.archivedAt = Date()
            issue.updatedAt = Date()
            try issue.update(db)
            return (issue, ActivityDraft(kind: .system, action: .archivedIssue, body: "Archived \(issue.identifier)", projectId: issue.projectId, issueId: issue.id))
        }
    }

    func restoreIssue(idOrIdentifier: String, actor: String) throws -> Issue {
        try mutate(actor: actor) { db in
            guard var issue = try Self.fetchIssue(db, idOrIdentifier) else { throw ValidationError.missingIssue }
            issue.archivedAt = nil
            issue.updatedAt = Date()
            try issue.update(db)
            return (issue, ActivityDraft(kind: .system, action: .restoredIssue, body: "Restored \(issue.identifier)", projectId: issue.projectId, issueId: issue.id))
        }
    }

    func addComment(idOrIdentifier: String, body: String, actor: String) throws -> Comment {
        let body = try Validation.requireBody(body, empty: .emptyComment)
        let who = Validation.actor(actor)
        let targets = Validation.mentions(in: body)
        let kind = Validation.commentKind(for: body, hasMentions: !targets.isEmpty)
        return try mutate(actor: who) { db in
            guard let issue = try Self.fetchIssue(db, idOrIdentifier) else { throw ValidationError.missingIssue }
            let comment = Comment(id: UUID().uuidString, issueId: issue.id, bodyMarkdown: body, author: who, createdAt: Date())
            try comment.insert(db)
            return (comment, ActivityDraft(kind: kind, action: .commented, body: body, targetActors: targets, projectId: issue.projectId, issueId: issue.id))
        }
    }

    func postNote(body: String, projectKey: String?, actor: String) throws -> Activity {
        let body = try Validation.requireBody(body, empty: .emptyNote)
        let targets = Validation.mentions(in: body)
        let kind = Validation.activityKind(for: body, hasMentions: !targets.isEmpty)
        let who = Validation.actor(actor)
        return try mutate(actor: who) { db in
            let project = try projectKey.flatMap { try Project.filter(Column("key") == $0.uppercased()).fetchOne(db) }
            let draft = ActivityDraft(kind: kind == .note && targets.isEmpty ? .note : kind, action: .noted, body: body, targetActors: targets, projectId: project?.id)
            let row = Activity(
                id: UUID().uuidString,
                createdAt: Date(),
                actor: who,
                kind: draft.kind,
                action: draft.action,
                body: draft.body,
                targetActors: Activity.encodeTargets(draft.targetActors),
                projectId: draft.projectId,
                issueId: nil,
                capabilityId: nil,
                milestoneId: nil
            )
            try row.insert(db)
            return (row, nil)
        }
    }

    // MARK: - Milestones

    func createMilestone(title: String, body: String, targetDate: String?, status: String, projectKey: String?, related: [String], actor: String) throws -> Milestone {
        let title = try Validation.collapseTitle(title)
        let status = try Validation.milestoneStatus(status)
        let date = try targetDate.map { try Validation.date($0) } ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let related = try Validation.studioIdentifiers(related)
        return try mutate(actor: actor) { db in
            try Self.requireExistingIssues(db, identifiers: related)
            let project: Project?
            if let projectKey, !projectKey.isEmpty, projectKey.lowercased() != "studio" {
                project = try Project.filter(Column("key") == projectKey.uppercased()).fetchOne(db)
                if project == nil { throw ValidationError.missingProject }
            } else {
                project = nil
            }
            let now = Date()
            let milestone = Milestone(
                id: UUID().uuidString,
                projectId: project?.id,
                title: title,
                bodyMarkdown: body,
                targetDate: date,
                status: status,
                relatedIssueIdentifiers: Milestone.encodeRelated(related),
                createdAt: now,
                updatedAt: now
            )
            try milestone.insert(db)
            return (milestone, ActivityDraft(kind: .system, action: .createdMilestone, body: "Created milestone \(title)", projectId: project?.id, milestoneId: milestone.id))
        }
    }

    func updateMilestone(id: String, title: String?, body: String?, targetDate: String?, status: String?, projectKey: String?, related: [String]?, actor: String) throws -> Milestone {
        if let status { _ = try Validation.milestoneStatus(status) }
        if let targetDate { _ = try Validation.date(targetDate) }
        if let title { _ = try Validation.collapseTitle(title) }
        return try mutate(actor: actor) { db in
            guard var milestone = try Milestone.fetchOne(db, key: id) else { throw ValidationError.missingMilestone }
            if let title { milestone.title = try Validation.collapseTitle(title) }
            if let body { milestone.bodyMarkdown = body }
            if let targetDate { milestone.targetDate = try Validation.date(targetDate) }
            if let status { milestone.status = try Validation.milestoneStatus(status) }
            if let related {
                let identifiers = try Validation.studioIdentifiers(related)
                try Self.requireExistingIssues(db, identifiers: identifiers)
                milestone.relatedIssueIdentifiers = Milestone.encodeRelated(identifiers)
            }
            if let projectKey {
                if projectKey.isEmpty || projectKey.lowercased() == "studio" {
                    milestone.projectId = nil
                } else if let project = try Project.filter(Column("key") == projectKey.uppercased()).fetchOne(db) {
                    milestone.projectId = project.id
                } else {
                    throw ValidationError.missingProject
                }
            }
            milestone.updatedAt = Date()
            try milestone.update(db)
            return (milestone, ActivityDraft(kind: .system, action: .updatedMilestone, body: "Updated milestone \(milestone.title)", projectId: milestone.projectId, milestoneId: milestone.id))
        }
    }

    // MARK: - Capabilities

    func createCapability(projectKey: String?, projectId: String?, title: String, note: String, state: String, health: String, docPath: String?, docAnchor: String?, linked: [String], actor: String) throws -> Capability {
        let title = try Validation.collapseTitle(title)
        let note = try Validation.capabilityNote(note)
        let state = try Validation.capabilityState(state)
        let health = try Validation.capabilityHealth(health)
        let linked = try Validation.studioIdentifiers(linked)
        return try mutate(actor: actor) { db in
            try Self.requireExistingIssues(db, identifiers: linked)
            var project = try Self.requireProject(db, key: projectKey, id: projectId)
            project.capabilityCounter += 1
            try project.update(db)
            let now = Date()
            let capability = Capability(
                id: UUID().uuidString,
                identifier: "\(project.key)-C\(project.capabilityCounter)",
                projectId: project.id,
                title: title,
                note: note,
                state: state,
                health: health,
                docPath: docPath,
                docAnchor: docAnchor,
                linkedIssueIdentifiers: Capability.encodeLinked(linked),
                sortOrder: Double(project.capabilityCounter),
                checkedAt: health == .unknown ? nil : now,
                createdAt: now,
                updatedAt: now
            )
            try capability.insert(db)
            return (capability, ActivityDraft(kind: .system, action: .createdCapability, body: "Created capability \(capability.identifier): \(title)", projectId: project.id, capabilityId: capability.id))
        }
    }

    func updateCapability(idOrIdentifier: String, title: String?, note: String?, state: String?, health: String?, docPath: String?, docAnchor: String?, linked: [String]?, actor: String) throws -> Capability {
        if let state { _ = try Validation.capabilityState(state) }
        if let health { _ = try Validation.capabilityHealth(health) }
        if let title { _ = try Validation.collapseTitle(title) }
        if let note { _ = try Validation.capabilityNote(note) }
        return try mutate(actor: actor) { db in
            guard var capability = try Capability.filter(Column("id") == idOrIdentifier || Column("identifier") == idOrIdentifier).fetchOne(db) else {
                throw ValidationError.missingCapability
            }
            if let title { capability.title = try Validation.collapseTitle(title) }
            if let note { capability.note = try Validation.capabilityNote(note) }
            if let state { capability.state = try Validation.capabilityState(state) }
            if let health {
                capability.health = try Validation.capabilityHealth(health)
                capability.checkedAt = Date()
            }
            if let docPath { capability.docPath = docPath }
            if let docAnchor { capability.docAnchor = docAnchor }
            if let linked {
                let identifiers = try Validation.studioIdentifiers(linked)
                try Self.requireExistingIssues(db, identifiers: identifiers)
                capability.linkedIssueIdentifiers = Capability.encodeLinked(identifiers)
            }
            capability.updatedAt = Date()
            try capability.update(db)
            return (capability, ActivityDraft(kind: .system, action: .updatedCapability, body: "Updated capability \(capability.identifier)", projectId: capability.projectId, capabilityId: capability.id))
        }
    }

    // MARK: - UI helpers

    func goToMonitorComposer() {
        sidebarSelection = .monitor
        focusComposer += 1
    }

    func goToIssuesSearch() {
        sidebarSelection = .issues
        focusIssueSearch += 1
    }

    func archiveFromUI(_ issue: Issue) {
        do {
            let archived = try archiveIssue(idOrIdentifier: issue.id, actor: "Riyu")
            undoArchive = UndoArchive(issue: archived, expiresAt: Date().addingTimeInterval(10))
        } catch {
            NSLog("Archive failed: \(error)")
        }
    }

    func undoArchiveIfNeeded() {
        guard let pending = undoArchive else { return }
        _ = try? restoreIssue(idOrIdentifier: pending.issue.id, actor: "Riyu")
        undoArchive = nil
    }

    func startServer() {
        let server = StudioServer(store: self)
        self.server = server
        do {
            try server.start()
            serverState = .listening
        } catch {
            serverState = .offline(reason: "port 7420 is in use")
            NSLog("Arkboard server failed: \(error)")
        }
    }

    // MARK: - Private DB helpers

    private static func requireProject(_ db: Database, key: String?, id: String?) throws -> Project {
        if let id, let project = try Project.fetchOne(db, key: id) { return project }
        if let key, let project = try Project.filter(Column("key") == key.uppercased()).fetchOne(db) { return project }
        throw ValidationError.missingProject
    }

    private static func fetchIssue(_ db: Database, _ value: String) throws -> Issue? {
        try Issue.filter(Column("id") == value || Column("identifier") == value).fetchOne(db)
    }

    private static func requireExistingIssues(_ db: Database, identifiers: [String]) throws {
        for identifier in identifiers {
            guard let issue = try Issue.filter(Column("identifier") == identifier).fetchOne(db), issue.archivedAt == nil else {
                throw ValidationError.unknownRelatedIssue(identifier)
            }
        }
    }

    private static func replaceLabels(_ db: Database, issueId: String, names: [String]) throws {
        try IssueLabel.filter(Column("issueId") == issueId).deleteAll(db)
        for name in names {
            let existing = try Label.filter(Column("name") == name).fetchOne(db)
            let label = try existing ?? {
                let created = Label(id: UUID().uuidString, name: name, color: Hue.hex(forLabel: name))
                try created.insert(db)
                return created
            }()
            try IssueLabel(issueId: issueId, labelId: label.id).insert(db)
        }
    }
}

enum SettingsKey {
    static let appearance = "arkboard.appearance"
    static let fontSize = "arkboard.fontSize"
    static let fontFamily = "arkboard.fontFamily"
    static let sidebarSelection = "arkboard.sidebarSelection"
    static let serverPort = "arkboard.serverPort"
}

struct UndoArchive: Equatable {
    var issue: Issue
    var expiresAt: Date
}
