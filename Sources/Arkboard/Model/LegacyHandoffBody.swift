import Foundation

/// Handoffs written before the body became comment-only carried a field dump —
/// `destination:`, `project:`, `tab:`, an ISO timestamp, sometimes the
/// selection quoted with nothing typed under it. Those rows are still in
/// Activity and no migration can invent the note the human never wrote, so
/// History hides them rather than showing machine output back to the person it
/// was captured from.
///
/// This is a reader, never a writer. Nothing here composes a body.
enum LegacyHandoffBody {
    static let dumpKeys = [
        "destination:", "project:", "tab:", "doc:", "heading:", "selected:", "at:",
    ]

    static func looksLikeDump(_ body: String) -> Bool {
        let lines = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let written = lines.filter { !$0.isEmpty }
        guard !written.isEmpty else { return false }

        for line in written {
            let lower = line.lowercased()
            if dumpKeys.contains(where: { lower.hasPrefix($0) }) { return true }
            if lower.hasPrefix("chief of staff handoff ·") { return true }
            if lower.hasPrefix("project · ") { return true }
        }
        // A bare selection quote with no note under it says nothing to a reader.
        return written.allSatisfy { $0.hasPrefix(">") }
    }
}
