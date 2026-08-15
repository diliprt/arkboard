import Foundation

enum ChiefOfStaffCopy {
    static let menuTitle = "Chat with Chief of Staff"
    static let sheetTitle = menuTitle
    static let targetActor = "Product"
}

struct PageFocus: Equatable, Sendable {
    var destination: String
    var projectKey: String?
    var projectName: String?
    var tab: String?
    var documentPath: String?
    var markdown: String?

    static let empty = PageFocus(destination: "portfolio")

    static func from(selection: SidebarItem?, projects: [Project]) -> PageFocus {
        switch selection {
        case .timeline:
            return PageFocus(destination: "timeline")
        case .onboarding:
            return PageFocus(destination: "onboarding", documentPath: "product/onboarding.md")
        case .project(let id):
            let project = projects.first { $0.id == id }
            return PageFocus(
                destination: "project",
                projectKey: project?.key,
                projectName: project?.name,
                tab: "Design"
            )
        case .portfolio, .none:
            return PageFocus(destination: "portfolio")
        }
    }
}

struct ChiefHandoff: Equatable, Sendable, Identifiable {
    var id: UUID
    var selectedText: String
    var destination: String
    var projectKey: String?
    var projectName: String?
    var tab: String?
    var documentPath: String?
    var nearestHeading: String?
    var pageLine: String
    var timestamp: Date

    static func capture(focus: PageFocus, selectedText: String, headingFallback: String?, at timestamp: Date = Date()) -> ChiefHandoff {
        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = nearestHeading(in: focus.markdown ?? "", selectedText: selected, fallback: headingFallback)
        return ChiefHandoff(
            id: UUID(),
            selectedText: selected,
            destination: focus.destination,
            projectKey: focus.projectKey,
            projectName: focus.projectName,
            tab: focus.tab,
            documentPath: focus.documentPath,
            nearestHeading: heading,
            pageLine: pageLine(
                projectName: focus.projectName,
                tab: focus.tab,
                documentPath: focus.documentPath,
                destination: focus.destination
            ),
            timestamp: timestamp
        )
    }

    static func pageLine(projectName: String?, tab: String?, documentPath: String?, destination: String) -> String {
        var parts: [String] = []
        if let projectName, !projectName.isEmpty {
            parts.append(projectName)
        } else if destination == "timeline" {
            parts.append("Timeline")
        } else if destination == "onboarding" {
            parts.append("Onboarding")
        } else {
            parts.append("Portfolio")
        }
        if let tab, !tab.isEmpty { parts.append(tab) }
        if let documentPath, !documentPath.isEmpty { parts.append(documentPath) }
        return parts.joined(separator: " · ")
    }

    static func nearestHeading(in markdown: String, selectedText: String, fallback: String?) -> String? {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var headings: [(Int, String)] = []
        var selectedLine: Int?
        for (index, line) in lines.enumerated() {
            let stripped = line.trimmingCharacters(in: .whitespaces)
            var hashes = 0
            while hashes < stripped.count {
                let idx = stripped.index(stripped.startIndex, offsetBy: hashes)
                if stripped[idx] == "#" { hashes += 1 } else { break }
            }
            if (1...6).contains(hashes), hashes < stripped.count {
                let after = stripped.index(stripped.startIndex, offsetBy: hashes)
                if stripped[after] == " " {
                    let title = String(stripped[stripped.index(after, offsetBy: 1)...]).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty { headings.append((index, title)) }
                }
            }
            if selectedLine == nil, !selectedText.isEmpty, line.contains(selectedText) {
                selectedLine = index
            }
        }
        if let selectedLine {
            let prior = headings.compactMap { $0.0 <= selectedLine ? $0.1 : nil }
            if let last = prior.last { return last }
        }
        if let fallback, !fallback.isEmpty { return fallback }
        return headings.first?.1
    }

    func persistBody(userText: String) -> String {
        Self.persistBody(
            userText: userText,
            selectedText: selectedText,
            destination: destination,
            projectKey: projectKey,
            projectName: projectName,
            tab: tab,
            documentPath: documentPath,
            nearestHeading: nearestHeading,
            pageLine: pageLine,
            timestamp: StudioISO8601.string(from: timestamp)
        )
    }

    static func persistBody(
        userText: String,
        selectedText: String,
        destination: String,
        projectKey: String?,
        projectName: String?,
        tab: String?,
        documentPath: String?,
        nearestHeading: String?,
        pageLine: String,
        timestamp: String
    ) -> String {
        var lines = [userText.trimmingCharacters(in: .whitespacesAndNewlines), ""]
        lines.append("Chief of Staff handoff · \(pageLine)")
        lines.append("destination: \(destination)")
        if let projectKey, !projectKey.isEmpty {
            let name = projectName.map { " \($0)" } ?? ""
            lines.append("project: \(projectKey)\(name)")
        }
        if let tab, !tab.isEmpty { lines.append("tab: \(tab)") }
        if let documentPath, !documentPath.isEmpty { lines.append("doc: \(documentPath)") }
        if let nearestHeading, !nearestHeading.isEmpty { lines.append("heading: \(nearestHeading)") }
        if !selectedText.isEmpty { lines.append("selected: \(selectedText)") }
        lines.append("at: \(timestamp)")
        return lines.joined(separator: "\n")
    }
}

struct NoteSheetRequest: Identifiable, Equatable {
    let id: UUID
    var project: Project?
    var draft: String
    var handoff: ChiefHandoff?

    init(id: UUID = UUID(), project: Project? = nil, draft: String = "", handoff: ChiefHandoff? = nil) {
        self.id = id
        self.project = project
        self.draft = draft
        self.handoff = handoff
    }
}
