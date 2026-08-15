import SwiftUI

struct EmptyStateView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var section: StudioSection
    var title: String
    var sentence: String
    var actionTitle: String? = nil
    var minHeight: CGFloat = 0
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: section.symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(section.hue.color(for: scheme).opacity(0.40))
            Text(title)
                .font(type.heading)
                .foregroundStyle(StudioColor.primary)
            Text(sentence)
                .font(type.callout)
                .foregroundStyle(StudioColor.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(type.bodyStrong)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
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
