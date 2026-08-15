import Foundation
import GRDB

enum AppDatabase {
    static let shared: DatabasePool = {
        do {
            return try makePool()
        } catch {
            fatalError("Unable to open Arkboard database: \(error)")
        }
    }()

    static func makePool(at path: String? = nil) throws -> DatabasePool {
        let dbURL: URL
        if let path {
            dbURL = URL(fileURLWithPath: path)
        } else {
            let fm = FileManager.default
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = appSupport.appendingPathComponent("Arkboard", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            dbURL = dir.appendingPathComponent("studio.sqlite")
        }

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let pool = try DatabasePool(path: dbURL.path, configuration: config)
        try migrator.migrate(pool)
        return pool
    }

    static var databasePath: String {
        let fm = FileManager.default
        let appSupport = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent("Arkboard/studio.sqlite").path
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "workspace") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "project") { t in
                t.column("id", .text).primaryKey()
                t.column("key", .text).notNull().unique()
                t.column("name", .text).notNull()
                t.column("color", .text).notNull().defaults(to: "#5A62D6")
                t.column("summary", .text).notNull().defaults(to: "")
                t.column("repoPath", .text)
                t.column("githubRepo", .text)
                t.column("issueCounter", .integer).notNull().defaults(to: 0)
                t.column("capabilityCounter", .integer).notNull().defaults(to: 0)
                t.column("sortOrder", .double).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "issue") { t in
                t.column("id", .text).primaryKey()
                t.column("identifier", .text).notNull().unique()
                t.column("projectId", .text).notNull().indexed().references("project", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("bodyMarkdown", .text).notNull().defaults(to: "")
                t.column("status", .text).notNull().defaults(to: "backlog").indexed()
                t.column("priority", .text).notNull().defaults(to: "none")
                t.column("assignee", .text)
                t.column("sortOrder", .double).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("completedAt", .datetime)
                t.column("archivedAt", .datetime).indexed()
            }
            try db.create(table: "label") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull().unique()
                t.column("color", .text).notNull()
            }
            try db.create(table: "issue_label") { t in
                t.column("issueId", .text).notNull().references("issue", onDelete: .cascade)
                t.column("labelId", .text).notNull().references("label", onDelete: .cascade)
                t.primaryKey(["issueId", "labelId"])
            }
            try db.create(table: "comment") { t in
                t.column("id", .text).primaryKey()
                t.column("issueId", .text).notNull().indexed().references("issue", onDelete: .cascade)
                t.column("bodyMarkdown", .text).notNull()
                t.column("author", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "milestone") { t in
                t.column("id", .text).primaryKey()
                t.column("projectId", .text).indexed().references("project", onDelete: .setNull)
                t.column("title", .text).notNull()
                t.column("bodyMarkdown", .text).notNull().defaults(to: "")
                t.column("targetDate", .datetime).notNull().indexed()
                t.column("status", .text).notNull().defaults(to: "planned")
                t.column("relatedIssueIdentifiers", .text).notNull().defaults(to: "[]")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "capability") { t in
                t.column("id", .text).primaryKey()
                t.column("identifier", .text).notNull().unique()
                t.column("projectId", .text).notNull().indexed().references("project", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("note", .text).notNull().defaults(to: "")
                t.column("state", .text).notNull().defaults(to: "not_started")
                t.column("health", .text).notNull().defaults(to: "unknown").indexed()
                t.column("docPath", .text)
                t.column("docAnchor", .text)
                t.column("linkedIssueIdentifiers", .text).notNull().defaults(to: "[]")
                t.column("sortOrder", .double).notNull().defaults(to: 0)
                t.column("checkedAt", .datetime)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "activity") { t in
                t.column("id", .text).primaryKey()
                t.column("createdAt", .datetime).notNull().indexed()
                t.column("actor", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("action", .text).notNull()
                t.column("body", .text).notNull()
                t.column("targetActors", .text).notNull().defaults(to: "[]")
                t.column("projectId", .text).indexed().references("project", onDelete: .setNull)
                t.column("issueId", .text).indexed().references("issue", onDelete: .setNull)
                t.column("capabilityId", .text).indexed().references("capability", onDelete: .setNull)
                t.column("milestoneId", .text).indexed().references("milestone", onDelete: .setNull)
            }
        }
        migrator.registerMigration("v2-project-icon") { db in
            try db.alter(table: "project") { t in
                t.add(column: "icon", .text).notNull().defaults(to: "circle.fill")
            }
            let rows = try Row.fetchAll(db, sql: "SELECT id, key, name, color FROM project ORDER BY sortOrder, name")
            var used = Set<String>()
            for row in rows {
                let key: String = row["key"]
                let name: String = row["name"]
                let color: String = row["color"]
                let mark = ProjectMark.assigned(key: key, name: name, usedSymbols: used, existingColor: color)
                used.insert(mark.symbol)
                try db.execute(
                    sql: "UPDATE project SET icon = ?, color = ? WHERE id = ?",
                    arguments: [mark.symbol, mark.color, row["id"]]
                )
            }
        }
        migrator.registerMigration("v3-project-pinned") { db in
            try db.alter(table: "project") { t in
                t.add(column: "pinned", .boolean).notNull().defaults(to: true)
            }
        }
        migrator.registerMigration("v4-activity-metadata") { db in
            try db.alter(table: "activity") { t in
                t.add(column: "metadata", .text).notNull().defaults(to: "{}")
            }
        }
        migrator.registerMigration("v5-milestone-dependencies") { db in
            try db.alter(table: "milestone") { t in
                t.add(column: "dependsOn", .text).notNull().defaults(to: "[]")
            }
        }
        return migrator
    }
}
