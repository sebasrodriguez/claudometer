import Foundation

struct CodexParser {
    /// Parse Codex /status output into UsageTiers.
    /// Expected format: "gpt-5.4 high · 100% left · ~/Projects/..."
    static func parse(_ rawOutput: String) -> ProviderUsageData {
        let cleaned = stripAnsiCodes(rawOutput)

        var tiers: [UsageTier] = []

        // Look for "X% left" pattern
        if let remaining = firstMatch(in: cleaned, pattern: "(\\d+)%\\s*left") {
            if let remainingPct = Double(remaining) {
                let usedPct = 100.0 - remainingPct
                tiers.append(UsageTier(
                    id: "usage",
                    label: "Usage",
                    percent: usedPct,
                    resetTime: nil,
                    colorName: "green"
                ))
            }
        }

        // Try to extract model name for context
        if let model = firstMatch(in: cleaned, pattern: "(gpt-[\\w.]+|o[34]-\\w+)") {
            // Update the tier label with model info
            if !tiers.isEmpty {
                tiers[0] = UsageTier(
                    id: "usage",
                    label: "Usage (\(model))",
                    percent: tiers[0].percent,
                    resetTime: tiers[0].resetTime,
                    colorName: "green"
                )
            }
        }

        return ProviderUsageData(tiers: tiers, rawOutput: cleaned)
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func stripAnsiCodes(_ text: String) -> String {
        var result = text
        if let cursorRight = try? NSRegularExpression(pattern: "\u{1b}\\[(\\d*)C") {
            for match in cursorRight.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
                guard let fullRange = Range(match.range, in: result) else { continue }
                let countStr = Range(match.range(at: 1), in: result).map { String(result[$0]) } ?? ""
                result.replaceSubrange(fullRange, with: String(repeating: " ", count: Int(countStr) ?? 1))
            }
        }
        for pattern in [
            "\u{1b}\\[[0-9;?]*[A-BD-Za-z]",
            "\u{1b}\\][^\u{07}\u{1b}]*[\u{07}]",
            "\u{1b}\\][^\u{1b}]*\u{1b}\\\\",
            "\u{1b}[()][A-Z0-9]",
            "\u{1b}[=>NOMDEHcn78]",
            "\\r",
        ] {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }
        return result.unicodeScalars.filter { $0 == "\n" || $0 == "\t" || $0.value >= 0x20 }.map { String($0) }.joined()
    }
}
