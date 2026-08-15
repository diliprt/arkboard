import AppKit
import SwiftUI

enum Hue: String, CaseIterable, Sendable {
    case rose, ember, gold, moss, teal, azure, indigo, violet, magenta, crimson, slate

    static let ramp: [Hue] = [.rose, .ember, .gold, .moss, .teal, .azure, .indigo, .violet, .magenta, .crimson]

    var light: String {
        switch self {
        case .rose: return "#D4436B"
        case .ember: return "#C2661F"
        case .gold: return "#A87908"
        case .moss: return "#1F8F63"
        case .teal: return "#12908C"
        case .azure: return "#2C6FCF"
        case .indigo: return "#5A62D6"
        case .violet: return "#8A54D6"
        case .magenta: return "#B23FA8"
        case .crimson: return "#C0392B"
        case .slate: return "#6E7781"
        }
    }

    var dark: String {
        switch self {
        case .rose: return "#F27897"
        case .ember: return "#F0975A"
        case .gold: return "#E0B94A"
        case .moss: return "#4FC694"
        case .teal: return "#3FC3BC"
        case .azure: return "#69A3F2"
        case .indigo: return "#8D93F2"
        case .violet: return "#B389F0"
        case .magenta: return "#DC79D0"
        case .crimson: return "#F2776A"
        case .slate: return "#9AA4AF"
        }
    }

    func hex(for scheme: ColorScheme) -> String {
        scheme == .dark ? dark : light
    }

    func color(for scheme: ColorScheme) -> Color {
        Color(hex: hex(for: scheme))
    }

    static func hex(forLabel name: String) -> String {
        actorHue(for: name).light
    }

    static func actorHue(for name: String) -> Hue {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "riyu": return .moss
        case "agent": return .azure
        case "cursor": return .violet
        case "grok": return .ember
        default:
            let hash = fnv1a(key)
            return ramp[Int(hash % UInt32(ramp.count))]
        }
    }

    static func fnv1a(_ string: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in string.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash
    }
}

enum StudioSection: String, CaseIterable, Sendable {
    case monitor, issues, activity, portfolio, onboarding
    case design, architecture, mockups, decisions, timeline

    var hue: Hue {
        switch self {
        case .monitor: return .indigo
        case .issues: return .teal
        case .activity: return .ember
        case .portfolio: return .violet
        case .onboarding: return .indigo
        case .design: return .rose
        case .architecture: return .azure
        case .mockups: return .magenta
        case .decisions: return .gold
        case .timeline: return .moss
        }
    }

    var symbol: String {
        switch self {
        case .monitor: return "binoculars"
        case .issues: return "tray.full"
        case .activity: return "bubble.left.and.bubble.right"
        case .portfolio: return "square.grid.2x2"
        case .onboarding: return "sparkles"
        case .design: return "paintpalette"
        case .architecture: return "square.stack.3d.up"
        case .mockups: return "photo.on.rectangle.angled"
        case .decisions: return "questionmark.bubble"
        case .timeline: return "calendar"
        }
    }

    var title: String {
        switch self {
        case .monitor: return "Monitor"
        case .issues: return "Issues"
        case .activity: return "Activity"
        case .portfolio: return "Portfolio"
        case .onboarding: return "Onboarding"
        case .design: return "Design"
        case .architecture: return "Architecture"
        case .mockups: return "Mockups"
        case .decisions: return "Decisions & questions"
        case .timeline: return "Timeline"
        }
    }
}

enum StudioColor {
    static var window: Color { Color(nsColor: .windowBackgroundColor) }
    static var card: Color { Color(nsColor: .controlBackgroundColor) }
    static var editor: Color { Color(nsColor: .textBackgroundColor) }
    static var hairline: Color { Color(nsColor: .separatorColor) }
    static var primary: Color { Color(nsColor: .labelColor) }
    static var secondary: Color { Color(nsColor: .secondaryLabelColor) }
    static var tertiary: Color { Color(nsColor: .tertiaryLabelColor) }

    static func wash(_ hue: Hue, scheme: ColorScheme) -> Color {
        hue.color(for: scheme).opacity(scheme == .dark ? 0.10 : 0.06)
    }

    static func cardStroke(_ hue: Hue, scheme: ColorScheme) -> Color {
        hue.color(for: scheme).opacity(scheme == .dark ? 0.20 : 0.14)
    }

    static func chipFill(_ hue: Hue, scheme: ColorScheme) -> Color {
        hue.color(for: scheme).opacity(scheme == .dark ? 0.18 : 0.12)
    }

    static func selectedTab(_ hue: Hue, scheme: ColorScheme) -> Color {
        hue.color(for: scheme).opacity(scheme == .dark ? 0.24 : 0.16)
    }

    static func divider(_ hue: Hue, scheme: ColorScheme) -> Color {
        hue.color(for: scheme).opacity(scheme == .dark ? 0.30 : 0.22)
    }

    static func tableHeader(_ hue: Hue, scheme: ColorScheme) -> Color {
        hue.color(for: scheme).opacity(0.08)
    }

    static func inlineCode(_ hue: Hue, scheme: ColorScheme) -> Color {
        hue.color(for: scheme).opacity(0.10)
    }

    static func shadow(scheme: ColorScheme) -> Color {
        Color.black.opacity(scheme == .dark ? 0.45 : 0.18)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
