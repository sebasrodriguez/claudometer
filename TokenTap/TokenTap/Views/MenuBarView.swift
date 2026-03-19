import SwiftUI

struct MenuBarView: View {
    @ObservedObject var manager: ProviderManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(manager.providers) { state in
                ProviderSection(state: state)
                Divider()
            }

            // Actions
            HStack {
                Button(action: { manager.refreshAll() }) {
                    Label("Refresh All", systemImage: "arrow.clockwise")
                }

                Spacer()

                Button(action: { SettingsWindowController.shared.show(manager: manager) }) {
                    Label("Settings", systemImage: "gear")
                }

                Spacer()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label("Quit", systemImage: "power")
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding()
        .frame(width: 300)
    }
}
