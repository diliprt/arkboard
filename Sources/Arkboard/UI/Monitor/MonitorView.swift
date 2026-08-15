import SwiftUI

struct MonitorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(section: .monitor, subtitle: "What needs you, and what is broken.")
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                    NoteComposer(allowStudioScope: true)
                    questions
                    broken
                    health
                }
                .padding(.horizontal, Metrics.paneX)
                .padding(.vertical, Metrics.paneY)
                .frame(maxWidth: Metrics.gridMax, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(StudioColor.wash(.indigo, scheme: scheme))
        }
    }

    @ViewBuilder
    private var questions: some View {
        let items = store.openQuestions
        VStack(alignment: .leading, spacing: 12) {
            Text("Open questions")
                .font(type.heading)
            + Text("  \(items.count)")
                .font(type.caption)
                .foregroundStyle(StudioColor.secondary)
            if items.isEmpty && store.brokenCapabilities.isEmpty {
                EmptyStateView(section: .monitor, title: EmptyCopy.quietStudio.0, sentence: EmptyCopy.quietStudio.1, layout: .poster)
            } else if items.isEmpty {
                EmptyStateView(section: .decisions, title: EmptyCopy.noQuestions.0, sentence: EmptyCopy.noQuestions.1, layout: .poster)
            } else {
                ForEach(items) { question in
                    Button {
                        store.sidebarSelection = .project(question.projectId)
                    } label: {
                        CardSurface(hue: .gold) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(question.heading)
                                        .font(type.bodyStrong)
                                        .foregroundStyle(StudioColor.primary)
                                    Chip(text: question.projectName, hue: Hue.actorHue(for: question.projectKey))
                                    ClampedMarkdown(markdown: question.body, hue: .gold, lines: 4)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(StudioColor.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var broken: some View {
        let items = store.brokenCapabilities
        VStack(alignment: .leading, spacing: 12) {
            Text("Not working")
                .font(type.heading)
            + Text("  \(items.count)")
                .font(type.caption)
                .foregroundStyle(StudioColor.secondary)
            if items.isEmpty {
                EmptyStateView(section: .issues, title: EmptyCopy.nothingBroken.0, sentence: EmptyCopy.nothingBroken.1, layout: .poster)
            } else {
                ForEach(items) { capability in
                    Button {
                        if let project = store.project(id: capability.projectId) {
                            store.sidebarSelection = .project(project.id)
                        }
                    } label: {
                        CardSurface(hue: .crimson) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(capability.title).font(type.bodyStrong)
                                    Text(capability.identifier).font(type.mono).foregroundStyle(StudioColor.secondary)
                                }
                                if let project = store.project(id: capability.projectId) {
                                    Chip(text: project.name, hue: .crimson)
                                }
                                if !capability.note.isEmpty {
                                    Text(capability.note).font(type.body).lineLimit(1)
                                }
                                if let checked = capability.checkedAt {
                                    Text("checked \(RelativeTime.format(checked))")
                                        .font(type.caption)
                                        .foregroundStyle(StudioColor.secondary)
                                }
                                HStack {
                                    ForEach(capability.linkedIdentifiers, id: \.self) { ident in
                                        Chip(text: ident, hue: .teal, mono: true)
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var health: some View {
        VStack(alignment: .leading, spacing: 6) {
            if store.serverState.isListening {
                Text("Agents listening on 127.0.0.1:7420")
                    .font(type.caption)
                    .foregroundStyle(Hue.moss.color(for: scheme))
            } else {
                Text("Agents offline — port 7420 is in use")
                    .font(type.caption)
                    .foregroundStyle(Hue.crimson.color(for: scheme))
            }
            ForEach(store.projects, id: \.id) { project in
                if let error = store.documentBundles[project.id]?.error {
                    Text("\(project.name): \(error)")
                        .font(type.caption)
                        .foregroundStyle(Hue.crimson.color(for: scheme))
                }
            }
        }
    }

}
