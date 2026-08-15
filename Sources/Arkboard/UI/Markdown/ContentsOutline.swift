import SwiftUI

/// Right-hand document contents. Click a heading to jump on the current page.
struct ContentsOutline: View {
    @Environment(AppStore.self) private var store
    @Environment(\.typography) private var type

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contents")
                .font(type.caption)
                .foregroundStyle(StudioColor.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 16)
            if store.documentOutline.isActive {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(store.documentOutline.headings, id: \.anchor) { heading in
                            Button {
                                store.jumpToHeading(heading.anchor)
                            } label: {
                                Text(heading.title)
                                    .font(heading.level <= 2 ? type.bodyStrong : type.caption)
                                    .foregroundStyle(StudioColor.primary)
                                    .multilineTextAlignment(.leading)
                                    .padding(.leading, CGFloat(max(0, heading.level - 1)) * 12)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 24)
                }
            } else {
                Text("This page has no subsections.")
                    .font(type.callout)
                    .foregroundStyle(StudioColor.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(StudioColor.window)
    }
}
