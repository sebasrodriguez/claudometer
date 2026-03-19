import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: ProviderManager

    var body: some View {
        TabView {
            GeneralSettingsView(manager: manager)
                .tabItem { Label("General", systemImage: "gear") }

            ClaudeSettingsView()
                .tabItem { Label("Claude", systemImage: "brain.head.profile") }
        }
        .padding()
        .frame(width: 400, height: 340)
    }
}

struct ClaudeSettingsView: View {
    @State private var binaryPath = UserDefaults.standard.string(forKey: "provider.claude.binaryPath") ?? ""
    @State private var refreshInterval = UserDefaults.standard.object(forKey: "provider.claude.refreshInterval") as? Double ?? 300

    var body: some View {
        Form {
            Section("Polling") {
                Picker("Refresh interval", selection: $refreshInterval) {
                    Text("1 min").tag(60.0)
                    Text("2 min").tag(120.0)
                    Text("5 min").tag(300.0)
                    Text("10 min").tag(600.0)
                    Text("15 min").tag(900.0)
                    Text("30 min").tag(1800.0)
                }
                .onChange(of: refreshInterval) {
                    UserDefaults.standard.set(refreshInterval, forKey: "provider.claude.refreshInterval")
                }
            }

            Section("Claude CLI") {
                HStack {
                    Text("Binary path")
                    Spacer()
                    TextField("Auto-detect", text: $binaryPath)
                        .frame(width: 200)
                        .textFieldStyle(.roundedBorder)
                }
                .onChange(of: binaryPath) {
                    UserDefaults.standard.set(binaryPath, forKey: "provider.claude.binaryPath")
                }
                Text("Leave empty to auto-detect from PATH")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
