import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var manager: ProviderManager

    var body: some View {
        Form {
            Section("Display") {
                Picker("Menu bar style", selection: $manager.displayMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                if manager.providers.count > 1 {
                    Picker("Rotation speed", selection: $manager.rotationInterval) {
                        Text("3 seconds").tag(3.0)
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                        Text("15 seconds").tag(15.0)
                    }
                }
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: $manager.notificationsEnabled)

                HStack {
                    Text("Warning at")
                    Spacer()
                    TextField("", value: $manager.warningThreshold, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                    Text("%")
                }

                HStack {
                    Text("Critical at")
                    Spacer()
                    TextField("", value: $manager.criticalThreshold, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                    Text("%")
                }
            }
        }
        .formStyle(.grouped)
    }
}
