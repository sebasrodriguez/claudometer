import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: ProviderManager

    var body: some View {
        TabView {
            GeneralSettingsView(manager: manager)
                .tabItem { Label("General", systemImage: "gear") }

            if let claude = manager.providers.first(where: { $0.kind == .claude }) {
                ProviderSettingsView(state: claude, authInfo: "Uses OAuth token from macOS Keychain (Claude Code-credentials)")
                    .tabItem { Label("Claude", systemImage: "brain.head.profile") }
            }

            if let codex = manager.providers.first(where: { $0.kind == .codex }) {
                ProviderSettingsView(state: codex, authInfo: "Uses access token from ~/.codex/auth.json")
                    .tabItem { Label("Codex", systemImage: "chevron.left.forwardslash.chevron.right") }
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

/// Reusable settings view for any provider.
struct ProviderSettingsView: View {
    @ObservedObject var state: ProviderState
    let authInfo: String

    var body: some View {
        Form {
            Section("Polling") {
                Picker("Refresh interval", selection: $state.refreshInterval) {
                    Text("1 min").tag(60.0)
                    Text("2 min").tag(120.0)
                    Text("5 min").tag(300.0)
                    Text("10 min").tag(600.0)
                    Text("15 min").tag(900.0)
                    Text("30 min").tag(1800.0)
                }
            }

            Section("Authentication") {
                Text(authInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
