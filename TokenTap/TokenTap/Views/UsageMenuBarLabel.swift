import SwiftUI

enum MenuBarDisplayMode: String, CaseIterable {
    case barAndText = "Bar + %"
    case bar = "Bar only"
    case textOnly = "Text only"
}

struct UsageMenuBarLabel: View {
    @ObservedObject var manager: ProviderManager

    private var state: ProviderState? { manager.displayedProvider }

    private var statusColor: Color {
        guard let pct = state?.primaryPercent else { return .primary }
        if pct >= manager.criticalThreshold { return Color(red: 0.95, green: 0.2, blue: 0.2) }
        if pct >= manager.warningThreshold { return Color(red: 0.85, green: 0.65, blue: 0.0) }
        return .primary
    }

    var body: some View {
        Group {
            switch manager.displayMode {
            case .barAndText:
                HStack(spacing: 5) {
                    Image(nsImage: BarRenderer.render(
                        percent: state?.primaryPercent,
                        warningThreshold: manager.warningThreshold,
                        criticalThreshold: manager.criticalThreshold
                    ))
                    .renderingMode(.original)
                    Text(state?.menuBarText ?? "TT --")
                        .monospacedDigit()
                        .foregroundColor(statusColor)
                }
            case .bar:
                Image(nsImage: BarRenderer.render(
                    percent: state?.primaryPercent,
                    warningThreshold: manager.warningThreshold,
                    criticalThreshold: manager.criticalThreshold
                ))
                .renderingMode(.original)
            case .textOnly:
                Text(state?.menuBarText ?? "TT --")
                    .monospacedDigit()
                    .foregroundColor(statusColor)
            }
        }
        .onAppear {
            manager.startAll()
        }
    }
}
