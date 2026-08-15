import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    private var markdown: String { store.onboardingMarkdown() }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScreenHeader(section: .onboarding, subtitle: "How this studio works.")
                ScrollView {
                    Group {
                        if markdown.isEmpty {
                            EmptyStateView(
                                section: .onboarding,
                                title: "Onboarding is not written yet",
                                sentence: "A director pass will write this.",
                                minHeight: Metrics.emptyPaneMin
                            )
                        } else {
                            MarkdownView(markdown: markdown, hue: .indigo)
                        }
                    }
                    .padding(Metrics.paneX)
                    .padding(.vertical, Metrics.paneY)
                    .frame(width: DocumentMeasure.pageWidth(paneWidth: geo.size.width), alignment: .leading)
                }
                .background(StudioColor.wash(.indigo, scheme: scheme))
            }
        }
        .frame(minWidth: Metrics.documentMin, maxWidth: .infinity, maxHeight: .infinity)
        .chiefOfStaffContextMenu()
        .task {
            if let ark = store.project(key: "ARK") {
                await store.ensureDocuments(projectId: ark.id)
            }
            publish()
        }
        .onChange(of: markdown) { _, _ in publish() }
    }

    private func publish() {
        store.publishOutline(headings: MarkdownParser.headings(in: markdown), hue: .indigo)
        store.publishPageFocus(PageFocus(
            destination: "onboarding",
            documentPath: "product/onboarding.md",
            markdown: markdown
        ))
    }
}
