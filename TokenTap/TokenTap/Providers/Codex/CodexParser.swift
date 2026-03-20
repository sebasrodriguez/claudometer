import Foundation

struct CodexParser {
    /// Convert rate limit headers into UsageTiers.
    static func parse(_ headers: CodexPoller.RateLimitHeaders) -> ProviderUsageData {
        var tiers: [UsageTier] = []

        // Primary limit (5h session)
        if let pct = headers.primaryUsedPercent {
            let windowLabel = headers.primaryWindowMinutes.map { "\($0 / 60)h" } ?? "5h"
            var resetStr: String?
            if let resetAt = headers.primaryResetAt {
                resetStr = formatReset(resetAt)
            }
            tiers.append(UsageTier(
                id: "primary",
                label: "\(windowLabel) Limit",
                percent: pct,
                resetTime: resetStr,
                colorName: "green"
            ))
        }

        // Secondary limit (weekly)
        if let pct = headers.secondaryUsedPercent {
            var resetStr: String?
            if let resetAt = headers.secondaryResetAt {
                resetStr = formatReset(resetAt)
            }
            tiers.append(UsageTier(
                id: "secondary",
                label: "Weekly Limit",
                percent: pct,
                resetTime: resetStr,
                colorName: "blue"
            ))
        }

        return ProviderUsageData(tiers: tiers, rawOutput: nil)
    }

    private static func formatReset(_ date: Date) -> String {
        let now = Date()
        let diff = date.timeIntervalSince(now)

        if diff <= 0 { return "now" }

        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60

        if hours > 24 {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d 'at' h:mma"
            return formatter.string(from: date)
        } else if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
}
