import Foundation

struct ClaudeParser {
    /// Parse Claude's /usage TUI output into provider-agnostic UsageTiers.
    static func parse(_ rawOutput: String) -> ProviderUsageData {
        let cleaned = stripAnsiCodes(rawOutput)
        let text = cleaned
        var tiers: [UsageTier] = []

        // --- Session usage ---
        var sessionPct: Double?
        var sessionReset: String?

        if let match = firstMatch(in: text, pattern: "(?i)Curren.?t?.?\\s+session.*?(\\d+)%\\s*used") {
            sessionPct = Double(match)
        }
        if let block = extractBlock(from: text, after: "(?i)Curren.?t?.?\\s+session", before: "(?i)Current week"),
           let reset = extractReset(from: block) {
            sessionReset = reset
        }

        // --- Weekly (all models) usage ---
        var weeklyPct: Double?
        var weeklyReset: String?

        if let match = firstMatch(in: text, pattern: "(?i)Current week \\(all model.*?(\\d+)%\\s*used") {
            weeklyPct = Double(match)
        }
        if let block = extractBlock(from: text, after: "(?i)Current week \\(all model", before: "(?i)Current week \\(Sonnet|Extra usage"),
           let reset = extractReset(from: block) {
            weeklyReset = reset
        }

        // --- Sonnet usage ---
        var sonnetPct: Double?
        if let match = firstMatch(in: text, pattern: "(?i)(?:Current week \\()?Sonnet.*?(\\d+)%\\s*used") {
            sonnetPct = Double(match)
        }

        // --- Fallback: positional matching ---
        let allPercents = allMatches(in: text, pattern: "(\\d+)%\\s*used")
        if sessionPct == nil, allPercents.count > 0 { sessionPct = Double(allPercents[0]) }
        if weeklyPct == nil, allPercents.count > 1 { weeklyPct = Double(allPercents[1]) }
        if sonnetPct == nil, allPercents.count > 2 { sonnetPct = Double(allPercents[2]) }

        let allResets = allMatches(in: text, pattern: "Rese[t ]?s?\\s+([^R]+?)(?=\\s{2,}|Curren|Extra|Esc|$)")
        if sessionReset == nil, allResets.count > 0 { sessionReset = allResets[0].trimmingCharacters(in: .whitespaces) }
        if weeklyReset == nil, allResets.count > 1 { weeklyReset = allResets[1].trimmingCharacters(in: .whitespaces) }

        // --- Build tiers ---
        if let pct = sessionPct {
            tiers.append(UsageTier(id: "session", label: "Session", percent: pct, resetTime: sessionReset, colorName: "green"))
        }
        if let pct = weeklyPct {
            tiers.append(UsageTier(id: "weekly", label: "Weekly", percent: pct, resetTime: weeklyReset, colorName: "blue"))
        }
        if let pct = sonnetPct {
            tiers.append(UsageTier(id: "weekly-sonnet", label: "Weekly (Sonnet)", percent: pct, resetTime: weeklyReset, colorName: "purple"))
        }

        return ProviderUsageData(tiers: tiers, rawOutput: cleaned)
    }

    // MARK: - Regex Helpers

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func extractBlock(from text: String, after: String, before: String) -> String? {
        guard let afterRegex = try? NSRegularExpression(pattern: after),
              let afterMatch = afterRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let startIdx = text.index(text.startIndex, offsetBy: afterMatch.range.location)
        if let beforeRegex = try? NSRegularExpression(pattern: before) {
            let searchRange = NSRange(startIdx..., in: text)
            for m in beforeRegex.matches(in: text, range: searchRange) {
                if m.range.location > afterMatch.range.location + afterMatch.range.length {
                    let endIdx = text.index(text.startIndex, offsetBy: m.range.location)
                    return String(text[startIdx..<endIdx])
                }
            }
        }
        return String(text[startIdx...])
    }

    private static func extractReset(from block: String) -> String? {
        let pattern = "Rese[t ]?s?\\s+(.+?)(?=\\s{2,}|Curren|Extra|Esc|\\n|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
              let range = Range(match.range(at: 1), in: block) else { return nil }
        let result = String(block[range]).trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? nil : result
    }

    // MARK: - ANSI Stripping

    static func stripAnsiCodes(_ text: String) -> String {
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
