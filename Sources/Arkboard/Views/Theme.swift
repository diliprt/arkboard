import SwiftUI
import AppKit

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0.37; g = 0.42; b = 0.82
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum ActorStyle {
    static func color(for name: String) -> Color {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "product": return Color(hex: "#5E6AD2")
        case "ops": return Color(hex: "#26B5CE")
        case "comms": return Color(hex: "#F2994A")
        case "riyu": return Color(hex: "#27AE60")
        case "agent": return Color(hex: "#BB87FC")
        default:
            // Stable-ish hue from name hash
            var hash: UInt64 = 0
            for u in name.unicodeScalars { hash = hash &* 31 &+ UInt64(u.value) }
            let hues: [String] = ["#EB5757", "#F2C94C", "#56CCF2", "#BB87FC", "#F2994A", "#6FCF97"]
            return Color(hex: hues[Int(hash % UInt64(hues.count))])
        }
    }

    static func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }
}

struct ActorAvatar: View {
    let name: String
    var size: CGFloat = 28

    var body: some View {
        Text(ActorStyle.initials(for: name))
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(ActorStyle.color(for: name))
            .clipShape(Circle())
            .accessibilityLabel(name)
    }
}
