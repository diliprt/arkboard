import SwiftUI

struct OutlineBar: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var headings: [HeadingRef]
    var hue: Hue
    var onJump: (String) -> Void

    var h2: [HeadingRef] { headings.filter { $0.level == 2 } }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(headings, id: \.anchor) { heading in
                    Button(heading.title) { onJump(heading.anchor) }
                }
            } label: {
                Text("On this page")
                    .font(type.caption)
                    .foregroundStyle(hue.color(for: scheme))
                    .padding(.horizontal, Metrics.chipX)
                    .padding(.vertical, Metrics.chipY)
                    .background(StudioColor.chipFill(hue, scheme: scheme), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(h2, id: \.anchor) { heading in
                        Button {
                            onJump(heading.anchor)
                        } label: {
                            Text(heading.title)
                                .font(type.caption)
                                .foregroundStyle(hue.color(for: scheme))
                                .padding(.horizontal, Metrics.chipX)
                                .padding(.vertical, Metrics.chipY)
                                .background(StudioColor.chipFill(hue, scheme: scheme), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.paneX)
        .padding(.vertical, 8)
    }
}
