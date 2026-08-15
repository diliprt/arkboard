import SwiftUI

struct ProjectNoteSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.typography) private var type
    @Environment(\.dismiss) private var dismiss
    var project: Project?
    var initialDraft: String = ""
    var handoff: ChiefHandoff? = nil

    /// What a human said, and only that. System rows are out, and so are the
    /// pre-#23 handoffs whose body is a field dump rather than a note.
    private var history: [Activity] {
        store.activities.filter { row in
            row.kind != .system
                && row.projectId == project?.id
                && !LegacyHandoffBody.looksLikeDump(row.body)
                && !row.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(ChiefOfStaffCopy.menuTitle).font(type.title)
            if let handoff {
                Text(handoff.pageLine)
                    .font(type.caption)
                    .foregroundStyle(StudioColor.tertiary)
            }
            NoteComposer(projectKey: project?.key, initialDraft: initialDraft, handoff: handoff)
            Text("History").font(type.heading)
            if history.isEmpty {
                Text("Nothing said yet.")
                    .font(type.callout)
                    .foregroundStyle(StudioColor.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(history) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    ActorChip(name: row.actor)
                                    Text(RelativeTime.format(row.createdAt))
                                        .font(type.caption)
                                        .foregroundStyle(StudioColor.secondary)
                                }
                                Text(row.body)
                                    .font(type.body)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 440, height: 520)
    }
}
