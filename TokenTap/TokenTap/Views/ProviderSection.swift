import SwiftUI

struct ProviderSection: View {
    @ObservedObject var state: ProviderState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: state.kind.iconName)
                    .foregroundColor(.accentColor)
                Text(state.kind.displayName)
                    .font(.headline)

                Spacer()

                if state.isPolling {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }

            if state.tiers.isEmpty && !state.isPolling {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(state.tiers) { tier in
                    UsageSection(
                        title: tier.label,
                        percent: tier.percent,
                        resetTime: tier.resetTime,
                        color: tier.resolvedColor,
                        isPolling: false
                    )
                }
            }

            if let error = state.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let updated = state.lastUpdated {
                Text("Updated \(updated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
