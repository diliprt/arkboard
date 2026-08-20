import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $store.appearance) {
                    Text("Light").tag(AppearancePreference.light)
                    Text("Dark").tag(AppearancePreference.dark)
                    Text("System").tag(AppearancePreference.system)
                }
                .pickerStyle(.segmented)
            }
            Section("Text") {
                Picker("Text size", selection: $store.fontSize) {
                    Text("12").tag(12)
                    Text("13 (default)").tag(13)
                    Text("14").tag(14)
                    Text("16").tag(16)
                }
                Picker("Text face", selection: $store.fontFamily) {
                    ForEach(FontFamilyID.allCases) { family in
                        Text(family.settingLabel).tag(family)
                    }
                }
                specimen
            }
            Section("Studio") {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(type.caption)
                        .foregroundStyle(OriginArkBrand.sageColor)
                    Text(store.workspace?.name ?? "Origin Ark")
                }
                ForEach(store.projects) { project in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ProjectIcon(project: project, imageData: store.markImage(for: project), size: 18)
                            Text(project.name)
                            Spacer()
                            Text(project.key)
                                .font(type.mono)
                                .foregroundStyle(StudioColor.secondary)
                        }
                        ProjectSourcesEditor(project: project, compact: true)
                    }
                    .padding(.vertical, 4)
                }
            }
            Section("Agents") {
                HStack {
                    Circle()
                        .fill((store.serverState.isListening ? Hue.moss : Hue.crimson).color(for: scheme))
                        .frame(width: 8, height: 8)
                    Text(store.serverState.isListening ? "Listening on 127.0.0.1:7420" : "Offline — port 7420 is in use")
                }
                copyRow("MCP endpoint", "http://127.0.0.1:7420/mcp")
                copyRow("REST base", "http://127.0.0.1:7420/api")
                copyRow("Database", AppDatabase.databasePath)
                VStack(alignment: .leading, spacing: 6) {
                    Text("stdio bridge")
                    Text("python3 <repo>/mcp/bridge.py")
                        .font(type.mono)
                        .padding(12)
                        .background(StudioColor.editor, in: RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("python3 <repo>/mcp/bridge.py", forType: .string)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: Metrics.settingsMin.width, minHeight: Metrics.settingsMin.height)
        .frame(width: Metrics.settingsDefault.width, height: Metrics.settingsDefault.height)
        .background(SettingsWindowClamp())
        .onAppear { SettingsWindowSizing.install() }
    }

    private var specimen: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A studio notebook").font(type.heading)
            Text("Body copy stays label colour. Washes carry the hue, not the prose.")
                .font(type.body)
                .lineSpacing(type.lineSpacing)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(Hue.rose.color(for: scheme))
                Text("A bullet at the current size")
                    .font(type.body)
            }
            Text("ARK-14")
                .font(type.mono)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(StudioColor.inlineCode(.rose, scheme: scheme), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(Metrics.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioColor.card, in: RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
    }

    private func copyRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).font(type.mono).lineLimit(1)
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            }
        }
    }

}
