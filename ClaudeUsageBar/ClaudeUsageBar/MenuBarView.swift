import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Session Usage Section
            UsageSection(
                title: "Session",
                percent: model.sessionUsagePercent,
                resetTime: model.sessionResetTime,
                color: model.statusColor,
                isPolling: model.isPolling && model.lastUpdated == nil
            )

            Divider()

            // Weekly Usage Section
            UsageSection(
                title: "Weekly",
                percent: model.weeklyUsagePercent,
                resetTime: model.weeklyResetTime,
                color: model.weeklyStatusColor,
                isPolling: model.isPolling && model.lastUpdated == nil
            )

            // Sonnet Usage Section (only show if there's data)
            if model.weeklySonnetPercent != nil {
                Divider()

                UsageSection(
                    title: "Weekly (Sonnet)",
                    percent: model.weeklySonnetPercent,
                    resetTime: model.weeklyResetTime,
                    color: .purple,
                    isPolling: false
                )
            }

            // Error display
            if let error = model.error {
                Divider()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Raw output (collapsible, for debugging)
            if let raw = model.rawOutput, model.sessionUsagePercent == nil {
                Divider()
                DisclosureGroup("Raw Output") {
                    ScrollView {
                        Text(raw)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }
                .font(.caption)
            }

            Divider()

            // Last updated
            if let updated = model.lastUpdated {
                Text("Updated \(updated, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Actions
            HStack {
                Button(action: { model.refreshNow() }) {
                    Label(model.isPolling ? "Refreshing..." : "Refresh Now",
                          systemImage: "arrow.clockwise")
                }
                .disabled(model.isPolling)

                Spacer()

                Button(action: { SettingsWindowController.shared.show(model: model) }) {
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
        .frame(width: 280)
    }
}

struct UsageSection: View {
    let title: String
    let percent: Double?
    let resetTime: String?
    let color: Color
    let isPolling: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            if isPolling {
                ProgressView()
                    .scaleEffect(0.7)
            } else if let pct = percent {
                ProgressView(value: min(pct, 100), total: 100)
                    .tint(color)

                HStack {
                    Text(String(format: "%.0f%% used", pct))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(color)

                    Spacer()

                    if pct < 100 {
                        Text(String(format: "%.0f%% remaining", 100 - pct))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if let reset = resetTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption2)
                        Text("Resets: \(reset)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            } else {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
