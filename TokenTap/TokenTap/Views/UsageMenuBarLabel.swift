import SwiftUI

enum MenuBarDisplayMode: String, CaseIterable {
    case barAndText = "Bar + %"
    case bar = "Bar only"
    case textOnly = "Text only"
}

struct UsageMenuBarLabel: View {
    @ObservedObject var manager: ProviderManager

    private var state: ProviderState? { manager.displayedProvider }

    var body: some View {
        Group {
            switch manager.displayMode {
            case .barAndText:
                HStack(spacing: 5) {
                    Image(nsImage: BarRenderer.render(percent: state?.primaryPercent))
                        .renderingMode(.original)
                    Text(state?.menuBarText ?? "TT --")
                        .monospacedDigit()
                }
            case .bar:
                Image(nsImage: BarRenderer.render(percent: state?.primaryPercent))
                    .renderingMode(.original)
            case .textOnly:
                Text(state?.menuBarText ?? "TT --")
                    .monospacedDigit()
            }
        }
        .onAppear {
            manager.startAll()
        }
    }
}
