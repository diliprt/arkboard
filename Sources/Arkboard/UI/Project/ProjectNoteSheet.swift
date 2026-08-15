import SwiftUI

struct ProjectNoteSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.typography) private var type
    @Environment(\.dismiss) private var dismiss
    var project: Project?
    var initialDraft: String = ""
    var handoff: ChiefHandoff? = nil

    private var history: [Activity] {
        store.activities.filter { $0.kind != .system && $0.projectId == project?.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Note").font(type.title)
            if let handoff {
                VStack(alignment: .leading, spacing: 2) {
                    Text(handoff.pageLine)
                    Text(handoff.quietMetadata)
                }
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
