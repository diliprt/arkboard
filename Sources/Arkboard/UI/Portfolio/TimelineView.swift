import SwiftUI

struct TimelineView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScreenHeader(section: .timeline, subtitle: "The studio calendar.")
                ScrollView {
                    TimelineCalendarView(projectId: nil)
                        .padding(Metrics.paneX)
                        .padding(.vertical, Metrics.paneY)
                        .frame(width: DocumentMeasure.pageWidth(paneWidth: geo.size.width), alignment: .leading)
                }
                .background(StudioColor.wash(.moss, scheme: scheme))
            }
        }
        .frame(minWidth: Metrics.documentMin, maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { store.clearOutline() }
    }
}
