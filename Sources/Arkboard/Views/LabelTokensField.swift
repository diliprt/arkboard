import SwiftUI

/// Compact tokenized label editor — chips + field; Return/comma commits a token.
struct LabelTokensField: View {
    @Binding var tokens: [String]
    var placeholder: String = "Add label"
    var onCommit: (() -> Void)? = nil

    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !tokens.isEmpty {
                FlowLabelChips(tokens: tokens) { name in
                    tokens.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
                    onCommit?()
                }
            }

            TextField(placeholder, text: $draft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commitDraft() }
                .onChange(of: draft) { _, newValue in
                    if newValue.contains(",") {
                        let parts = newValue.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
                        if parts.count > 1 {
                            for part in parts.dropLast() {
                                addToken(part)
                            }
                            draft = parts.last ?? ""
                            onCommit?()
                        }
                    }
                }
        }
    }

    private func commitDraft() {
        addToken(draft)
        draft = ""
        onCommit?()
    }

    private func addToken(_ raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if !tokens.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            tokens.append(name)
        }
    }
}

/// Simple wrapping chip row without a third-party layout helper.
private struct FlowLabelChips: View {
    let tokens: [String]
    var onRemove: (String) -> Void

    var body: some View {
        // Prefer a wrapping layout when available (macOS 14+ Layout protocol via ViewThatFits / HStack wrap)
        FlexibleChipWrap(tokens: tokens, onRemove: onRemove)
    }
}

private struct FlexibleChipWrap: View {
    let tokens: [String]
    var onRemove: (String) -> Void

    var body: some View {
        // macOS 14+: use Layout-based wrap via View builder stacking rows by measuring with PreferenceKey is heavy;
        // a pragmatic wrap: use a single HStack that wraps via `wrappingHStack` approximation with LazyVGrid.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 64), spacing: 6, alignment: .leading)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(tokens, id: \.self) { name in
                HStack(spacing: 4) {
                    Text(name)
                        .font(.caption)
                        .lineLimit(1)
                    Button {
                        onRemove(name)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove \(name)")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
            }
        }
    }
}
