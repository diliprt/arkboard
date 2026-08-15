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

/// Quiet section accents — colorful, not a circus.
enum StudioSection: String, CaseIterable, Identifiable {
    case monitor, issues, activity, portfolio
    case overview, design, architecture, mockups, decisions, timeline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monitor: return "Monitor"
        case .issues: return "Issues"
        case .activity: return "Activity"
        case .portfolio: return "Portfolio"
        case .overview: return "Overview"
        case .design: return "Design"
        case .architecture: return "Architecture"
        case .mockups: return "Mockups"
        case .decisions: return "Decisions"
        case .timeline: return "Timeline"
        }
    }

    var symbol: String {
        switch self {
        case .monitor: return "binoculars"
        case .issues: return "tray"
        case .activity: return "bubble.left.and.bubble.right"
        case .portfolio: return "square.grid.2x2"
        case .overview: return "text.alignleft"
        case .design: return "paintpalette"
        case .architecture: return "square.stack.3d.up"
        case .mockups: return "photo.on.rectangle"
        case .decisions: return "questionmark.bubble"
        case .timeline: return "calendar"
        }
    }

    var hex: String {
        switch self {
        case .monitor: return "#5B6CFF"
        case .issues: return "#1AA6A6"
        case .activity: return "#E07A3D"
        case .portfolio: return "#8B5CF6"
        case .overview: return "#3D8BFF"
        case .design: return "#E85D75"
        case .architecture: return "#3B82C4"
        case .mockups: return "#A855F7"
        case .decisions: return "#D4A017"
        case .timeline: return "#2F9E6A"
        }
    }

    var accent: Color { Color(hex: hex) }

    var wash: Color { accent.opacity(0.08) }
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

enum AppearancePreference: String, CaseIterable, Identifiable {
    case light, dark, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    private static let defaultsKey = "arkboard.appearance"

    static func load() -> AppearancePreference {
        let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? "light"
        return AppearancePreference(rawValue: raw) ?? .light
    }

    func persist() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}

enum AppFontSize: Int, CaseIterable, Identifiable {
    case twelve = 12
    case thirteen = 13
    case fourteen = 14
    case sixteen = 16

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .thirteen: return "13 pt (Default)"
        default: return "\(rawValue) pt"
        }
    }

    var points: CGFloat { CGFloat(rawValue) }

    private static let defaultsKey = "arkboard.fontSize"

    static func load() -> AppFontSize {
        let raw = UserDefaults.standard.object(forKey: defaultsKey) as? Int ?? 13
        return AppFontSize(rawValue: raw) ?? .thirteen
    }

    func persist() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}

/// Real macOS faces only — no web fonts, no downloads.
enum AppFontFamily: String, CaseIterable, Identifiable {
    case system
    case newYork
    case rounded
    case helveticaNeue
    case georgia
    case avenirNext
    case menlo
    case sfMono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System (SF Pro)"
        case .newYork: return "New York"
        case .rounded: return "SF Rounded"
        case .helveticaNeue: return "Helvetica Neue"
        case .georgia: return "Georgia"
        case .avenirNext: return "Avenir Next"
        case .menlo: return "Menlo"
        case .sfMono: return "SF Mono"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: weight, design: .default)
        case .newYork:
            return .system(size: size, weight: weight, design: .serif)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .sfMono:
            return .system(size: size, weight: weight, design: .monospaced)
        case .helveticaNeue:
            return Font.custom("Helvetica Neue", size: size)
        case .georgia:
            return Font.custom("Georgia", size: size)
        case .avenirNext:
            return Font.custom("Avenir Next", size: size)
        case .menlo:
            return Font.custom("Menlo", size: size)
        }
    }

    private static let defaultsKey = "arkboard.fontFamily"

    static func load() -> AppFontFamily {
        let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? "system"
        return AppFontFamily(rawValue: raw) ?? .system
    }

    func persist() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}

enum AppTypography {
    static func font(size: AppFontSize, family: AppFontFamily, weight: Font.Weight = .regular) -> Font {
        family.font(size: size.points, weight: weight)
    }

    static func mono(size: AppFontSize) -> Font {
        .system(size: size.points, design: .monospaced)
    }
}

private struct AppFontSizeKey: EnvironmentKey {
    static let defaultValue: AppFontSize = .thirteen
}

private struct AppFontFamilyKey: EnvironmentKey {
    static let defaultValue: AppFontFamily = .system
}

extension EnvironmentValues {
    var appFontSize: AppFontSize {
        get { self[AppFontSizeKey.self] }
        set { self[AppFontSizeKey.self] = newValue }
    }

    var appFontFamily: AppFontFamily {
        get { self[AppFontFamilyKey.self] }
        set { self[AppFontFamilyKey.self] = newValue }
    }
}

struct AppTypographyModifier: ViewModifier {
    let size: AppFontSize
    let family: AppFontFamily

    func body(content: Content) -> some View {
        content
            .font(AppTypography.font(size: size, family: family))
            .environment(\.font, AppTypography.font(size: size, family: family))
            .environment(\.appFontSize, size)
            .environment(\.appFontFamily, family)
    }
}

extension View {
    func appTypography(size: AppFontSize, family: AppFontFamily) -> some View {
        modifier(AppTypographyModifier(size: size, family: family))
    }

    func appBodyFont(weight: Font.Weight = .regular) -> some View {
        modifier(AppBodyFontModifier(weight: weight))
    }

    func sectionWash(_ section: StudioSection) -> some View {
        background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                section.wash
            }
            .ignoresSafeArea()
        }
    }
}

private struct AppBodyFontModifier: ViewModifier {
    @Environment(\.appFontSize) private var size
    @Environment(\.appFontFamily) private var family
    var weight: Font.Weight = .regular

    func body(content: Content) -> some View {
        content.font(AppTypography.font(size: size, family: family, weight: weight))
    }
}

struct ActorStackLite: View {
    let names: [String]
    var size: CGFloat = 18
    var maxVisible: Int = 3

    var body: some View {
        if names.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: -5) {
                ForEach(Array(names.prefix(maxVisible).enumerated()), id: \.offset) { _, name in
                    ActorAvatar(name: name, size: size)
                }
                if names.count > maxVisible {
                    Text("+\(names.count - maxVisible)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 6)
                }
            }
            .accessibilityLabel(names.joined(separator: ", "))
        }
    }
}

struct SectionHeader: View {
    let section: StudioSection
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: section.symbol)
                .foregroundStyle(section.accent)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.title2.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}
