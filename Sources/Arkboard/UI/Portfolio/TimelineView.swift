import SwiftUI

struct TimelineView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScreenHeader(section: .timeline, subtitle: "Every project on one timeline.")
                ScrollView {
                    TimelineGanttView(projectId: nil)
                        .padding(Metrics.paneX)
                        .padding(.vertical, Metrics.paneY)
                        .frame(width: DocumentMeasure.pageWidth(paneWidth: geo.size.width), alignment: .leading)
                }
                .paneBackground(StudioColor.wash(.moss, scheme: scheme))
            }
        }
        .frame(minWidth: Metrics.documentMin, maxWidth: .infinity, maxHeight: .infinity)
        .chiefOfStaffContextMenu()
        .onAppear {
            store.clearOutline()
            store.publishPageFocus(PageFocus(destination: "timeline"))
        }
    }
}
