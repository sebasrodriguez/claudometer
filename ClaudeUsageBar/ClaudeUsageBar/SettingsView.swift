import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        Form {
            Section("Display") {
                Picker("Menu bar style", selection: $model.displayMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }

            Section("Polling") {
                Picker("Refresh interval", selection: $model.refreshInterval) {
                    Text("1 min").tag(60.0)
                    Text("2 min").tag(120.0)
                    Text("5 min").tag(300.0)
                    Text("10 min").tag(600.0)
                    Text("15 min").tag(900.0)
                    Text("30 min").tag(1800.0)
                }
                .onChange(of: model.refreshInterval) {
                    model.scheduleTimer()
                }
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: $model.notificationsEnabled)

                HStack {
                    Text("Warning at")
                    Spacer()
                    TextField("", value: $model.warningThreshold, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                    Text("%")
                }

                HStack {
                    Text("Critical at")
                    Spacer()
                    TextField("", value: $model.criticalThreshold, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                    Text("%")
                }
            }

            Section("Claude CLI") {
                HStack {
                    Text("Binary path")
                    Spacer()
                    TextField("Auto-detect", text: $model.claudeBinaryPath)
                        .frame(width: 180)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Leave empty to auto-detect from PATH")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
