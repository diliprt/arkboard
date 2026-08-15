import SwiftUI

enum EmptyStateLayout {
    case document
    case poster
}

struct EmptyStateView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var section: StudioSection
    var title: String
    var sentence: String
    var actionTitle: String? = nil
    var minHeight: CGFloat = 0
    var layout: EmptyStateLayout = .document
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: layout == .poster ? .center : .leading, spacing: layout == .poster ? 12 : 8) {
            if layout == .poster {
                // Only a centred full-pane poster leads with the big symbol. In
                // a document tab that row sits above the first line and pushes
                // the whole pane down — it is what dropped the Mockups body 52pt
                // below Design's, and every tab has to share one origin.
                Image(systemName: section.symbol)
                    .font(type.face(size: type.bodySize + 15, weight: .medium))
                    .foregroundStyle(section.hue.color(for: scheme).opacity(0.40))
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if layout == .document {
                    // Section identity stays, on the title's own line, at the
                    // title's own size, so it adds no height above it.
                    Image(systemName: section.symbol)
                        .font(type.heading)
                        .foregroundStyle(section.hue.color(for: scheme).opacity(0.55))
                }
                Text(title)
                    .font(type.heading)
                    .foregroundStyle(StudioColor.primary)
            }
            Text(sentence)
                .font(type.callout)
                .foregroundStyle(StudioColor.secondary)
                .multilineTextAlignment(layout == .poster ? .center : .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(type.bodyStrong)
            }
        }
        .padding(layout == .poster ? 40 : 0)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: layout == .poster ? .center : .topLeading)
        .chiefOfStaffContextMenu()
    }
}

enum EmptyCopy {
    static let noProjects = ("No projects yet", "Create one and point it at a repository with a product/ folder.")
    static let noQuestions = ("No open questions", "Nothing is waiting on you right now.")
    static let nothingBroken = ("Nothing is broken", "Every capability agents have checked is working.")
    static let quietStudio = ("Quiet studio", "No open questions and nothing broken. Say something to the team above.")
    static let design = ("Design is not written yet", "A director pass will write this.")
    static let architecture = ("Architecture is not written yet", "A director pass will write this.")
    static let mockups = ("No mockups yet", "A director pass will drop screenshots here.")
    static let decisions = ("No decisions written yet", "A director pass will write this.")
    static let overview = ("No overview yet", "A director pass will write this.")
    static let noIssues = ("No issues", "Nothing has been filed here.")
    static let noMatch = ("No matching issues", "Try a different search or widen the scope.")
    static let nothingArchived = ("Nothing archived", "Archived issues stay here until an agent restores them.")
    static let selectIssue = ("Select an issue", "Pick one from the list to read it.")
    static let noBody = "No description yet."
    static let noComments = "No comments yet."
    static let noActivity = ("Nothing said yet", "Notes from you and from agents show up here.")
    static let noTimeline = ("Nothing planned yet", "Milestones and shipped work appear here.")
    static let portfolioEmpty = ("No projects yet", "Create one to see it here.")
}
