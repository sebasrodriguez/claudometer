import SwiftUI

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
