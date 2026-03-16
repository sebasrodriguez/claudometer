import SwiftUI

enum MenuBarDisplayMode: String, CaseIterable {
    case barAndText = "Bar + %"
    case bar = "Bar only"
    case textOnly = "Text only"
}

struct UsageMenuBarLabel: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        Group {
            switch model.displayMode {
            case .barAndText:
                HStack(spacing: 5) {
                    Image(nsImage: BarRenderer.render(
                        percent: model.sessionUsagePercent
                    ))
                    .renderingMode(.original)
                    Text(model.menuBarText)
                        .monospacedDigit()
                }
            case .bar:
                Image(nsImage: BarRenderer.render(
                    percent: model.sessionUsagePercent
                ))
                .renderingMode(.original)
            case .textOnly:
                Text(model.menuBarText)
                    .monospacedDigit()
            }
        }
        .onAppear {
            model.startPolling()
        }
    }
}
