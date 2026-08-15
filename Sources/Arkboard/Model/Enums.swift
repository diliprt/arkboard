import Foundation

enum IssueStatus: String, Codable, CaseIterable, Sendable {
    case backlog
    case todo
    case inProgress = "in_progress"
    case done
    case canceled
}

enum IssuePriority: String, Codable, CaseIterable, Sendable {
    case none
    case low
    case medium
    case high
    case urgent
}

enum MilestoneStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case inProgress = "in_progress"
    case done
    case missed
}

enum CapabilityState: String, Codable, CaseIterable, Sendable {
    case notStarted = "not_started"
    case building
    case built
}

enum CapabilityHealth: String, Codable, CaseIterable, Sendable {
    case unknown
    case working
    case notWorking = "not_working"
}

enum ActivityKind: String, Codable, CaseIterable, Sendable {
    case note
    case comment
    case mention
    case handoff
    case system
}

enum ActivityAction: String, Codable, CaseIterable, Sendable {
    case createdProject = "created_project"
    case createdIssue = "created_issue"
    case updatedIssue = "updated_issue"
    case archivedIssue = "archived_issue"
    case restoredIssue = "restored_issue"
    case commented
    case noted
    case createdMilestone = "created_milestone"
    case updatedMilestone = "updated_milestone"
    case createdCapability = "created_capability"
    case updatedCapability = "updated_capability"
}

enum DocumentTab: String, Codable, CaseIterable, Sendable {
    case overview
    case design
    case architecture
    case mockups
    case decisions
    case more
}

enum AppearancePreference: String, CaseIterable, Sendable {
    case light
    case dark
    case system
}

enum FontFamilyID: String, CaseIterable, Identifiable, Sendable {
    case system
    case newYork
    case rounded
    case sfMono
    case helveticaNeue
    case georgia
    case avenirNext
    case menlo

    var id: String { rawValue }

    var settingLabel: String {
        switch self {
        case .system: return "System (SF Pro)"
        case .newYork: return "New York"
        case .rounded: return "SF Rounded"
        case .sfMono: return "SF Mono"
        case .helveticaNeue: return "Helvetica Neue"
        case .georgia: return "Georgia"
        case .avenirNext: return "Avenir Next"
        case .menlo: return "Menlo"
        }
    }
}

enum SidebarItem: Hashable, Sendable {
    case project(String)

    var projectId: String {
        switch self {
        case .project(let id): return id
        }
    }

    var persistenceValue: String {
        "project:\(projectId)"
    }

    static func from(persistence value: String) -> SidebarItem? {
        guard value.hasPrefix("project:") else { return nil }
        let id = String(value.dropFirst("project:".count))
        return id.isEmpty ? nil : .project(id)
    }
}

enum ServerListenState: Equatable, Sendable {
    case listening
    case offline(reason: String)

    var isListening: Bool {
        if case .listening = self { return true }
        return false
    }
}
