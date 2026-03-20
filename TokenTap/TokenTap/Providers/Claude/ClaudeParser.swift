import Foundation

struct ClaudeParser {
    /// Convert the OAuth usage API response into UsageTiers.
    static func parse(_ response: ClaudePoller.UsageResponse) -> ProviderUsageData {
        var tiers: [UsageTier] = []

        if let fiveHour = response.five_hour {
            tiers.append(UsageTier(
                id: "session",
                label: "Session",
                percent: fiveHour.utilization,
                resetTime: formatResetTime(fiveHour.resets_at),
                colorName: "green"
            ))
        }

        if let sevenDay = response.seven_day {
            tiers.append(UsageTier(
                id: "weekly",
                label: "Weekly",
                percent: sevenDay.utilization,
                resetTime: formatResetTime(sevenDay.resets_at),
                colorName: "blue"
            ))
        }

        if let sonnet = response.seven_day_sonnet {
            tiers.append(UsageTier(
                id: "weekly-sonnet",
                label: "Weekly (Sonnet)",
                percent: sonnet.utilization,
                resetTime: formatResetTime(sonnet.resets_at),
                colorName: "purple"
            ))
        }

        if let opus = response.seven_day_opus {
            tiers.append(UsageTier(
                id: "weekly-opus",
                label: "Weekly (Opus)",
                percent: opus.utilization,
                resetTime: formatResetTime(opus.resets_at),
                colorName: "orange"
            ))
        }

        return ProviderUsageData(tiers: tiers, rawOutput: nil)
    }

    private static func formatResetTime(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first, then without
        guard let date = isoFormatter.date(from: isoString)
                ?? ISO8601DateFormatter().date(from: isoString) else {
            return isoString
        }

        let now = Date()
        let diff = date.timeIntervalSince(now)

        if diff <= 0 { return "now" }

        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60

        if hours > 24 {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d 'at' h:mma"
            formatter.timeZone = .current
            return formatter.string(from: date)
        } else if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
}
