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

    static func makePool() throws -> DatabasePool {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Arkboard", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("arkboard.sqlite")

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
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent("Arkboard/arkboard.sqlite").path
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
                t.column("color", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("issueCounter", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "issue") { t in
                t.column("id", .text).primaryKey()
                t.column("identifier", .text).notNull().unique()
                t.column("projectId", .text).notNull().indexed()
                    .references("project", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("descriptionMarkdown", .text).notNull().defaults(to: "")
                t.column("status", .text).notNull().indexed()
                t.column("priority", .text).notNull().indexed()
                t.column("assigneeName", .text)
                t.column("estimatePoints", .integer)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull().indexed()
                t.column("orderInStatus", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "label") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull().unique()
                t.column("color", .text).notNull()
            }

            try db.create(table: "issue_label") { t in
                t.column("issueId", .text).notNull()
                    .references("issue", onDelete: .cascade)
                t.column("labelId", .text).notNull()
                    .references("label", onDelete: .cascade)
                t.primaryKey(["issueId", "labelId"])
            }

            try db.create(table: "comment") { t in
                t.column("id", .text).primaryKey()
                t.column("issueId", .text).notNull().indexed()
                    .references("issue", onDelete: .cascade)
                t.column("bodyMarkdown", .text).notNull()
                t.column("authorName", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v2_activity") { db in
            try db.create(table: "activity") { t in
                t.column("id", .text).primaryKey()
                t.column("createdAt", .datetime).notNull().indexed()
                t.column("actor", .text).notNull().indexed()
                t.column("action", .text).notNull().indexed()
                t.column("issueId", .text).indexed()
                    .references("issue", onDelete: .setNull)
                t.column("projectId", .text).indexed()
                    .references("project", onDelete: .setNull)
                t.column("summary", .text).notNull()
            }
        }

        migrator.registerMigration("v3_milestones_activity_targets") { db in
            try db.create(table: "milestone") { t in
                t.column("id", .text).primaryKey()
                t.column("projectId", .text).indexed()
                    .references("project", onDelete: .setNull)
                t.column("title", .text).notNull()
                t.column("description", .text).notNull().defaults(to: "")
                t.column("targetDate", .datetime).notNull().indexed()
                t.column("status", .text).notNull().indexed()
                t.column("relatedIssueIdentifiers", .text).notNull().defaults(to: "[]")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            try db.alter(table: "activity") { t in
                t.add(column: "targetActor", .text)
                t.add(column: "kind", .text).notNull().defaults(to: "system")
            }
        }

        migrator.registerMigration("v4_issue_completed_at") { db in
            // Idempotent: SQLite DDL may persist even if a prior migration attempt failed.
            let columns = try Set(db.columns(in: "issue").map(\.name))
            if !columns.contains("completedAt") {
                try db.alter(table: "issue") { t in
                    t.add(column: "completedAt", .datetime)
                }
            }
            try db.execute(
                sql: "UPDATE issue SET completedAt = updatedAt WHERE status = 'done' AND completedAt IS NULL"
            )
        }

        migrator.registerMigration("v5_issue_deleted_at") { db in
            let columns = try Set(db.columns(in: "issue").map(\.name))
            if !columns.contains("deletedAt") {
                try db.alter(table: "issue") { t in
                    t.add(column: "deletedAt", .datetime)
                }
            }
        }
        return migrator
    }
}
