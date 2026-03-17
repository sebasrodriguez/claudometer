import Foundation

struct UsageParser {
    /// Parse the raw output from Claude's /usage command into structured data.
    /// Uses regex on the full text to handle both multi-line and single-line output formats.
    static func parse(_ rawOutput: String) -> UsageData {
        let cleaned = stripAnsiCodes(rawOutput)
        var data = UsageData()
        data.rawOutput = cleaned

        let text = cleaned

        // Extract session usage: look for "Current session" ... "X% used"
        if let match = firstMatch(in: text, pattern: "(?i)Curren.?t?.?\\s+session.*?(\\d+)%\\s*used") {
            data.sessionUsagePercent = Double(match)
        }

        // Extract session reset: look for "Resets" after "session" and before "Current week"
        if let sessionBlock = extractBlock(from: text, after: "(?i)Curren.?t?.?\\s+session", before: "(?i)Current week"),
           let reset = extractReset(from: sessionBlock) {
            data.sessionResetTime = reset
        }

        // Extract weekly (all models) usage
        if let match = firstMatch(in: text, pattern: "(?i)Current week \\(all model.*?(\\d+)%\\s*used") {
            data.weeklyUsagePercent = Double(match)
        }

        // Extract weekly reset
        if let weeklyBlock = extractBlock(from: text, after: "(?i)Current week \\(all model", before: "(?i)Current week \\(Sonnet|Extra usage"),
           let reset = extractReset(from: weeklyBlock) {
            data.weeklyResetTime = reset
        }

        // Extract Sonnet usage
        if let match = firstMatch(in: text, pattern: "(?i)(?:Current week \\()?Sonnet.*?(\\d+)%\\s*used") {
            data.weeklySonnetPercent = Double(match)
        }

        // Fallback: if section-based matching failed, try positional matching
        // Look for all "X% used" patterns in order: first=session, second=weekly, third=sonnet
        if data.sessionUsagePercent == nil || data.weeklyUsagePercent == nil {
            let allPercents = allMatches(in: text, pattern: "(\\d+)%\\s*used")
            if data.sessionUsagePercent == nil, allPercents.count > 0 {
                data.sessionUsagePercent = Double(allPercents[0])
            }
            if data.weeklyUsagePercent == nil, allPercents.count > 1 {
                data.weeklyUsagePercent = Double(allPercents[1])
            }
            if data.weeklySonnetPercent == nil, allPercents.count > 2 {
                data.weeklySonnetPercent = Double(allPercents[2])
            }
        }

        // Fallback for reset times: find all "Rese.?t?s? ..." patterns
        if data.sessionResetTime == nil || data.weeklyResetTime == nil {
            let allResets = allMatches(in: text, pattern: "Rese[t ]?s?\\s+([^R]+?)(?=\\s{2,}|Curren|Extra|Esc|$)")
            if data.sessionResetTime == nil, allResets.count > 0 {
                data.sessionResetTime = allResets[0].trimmingCharacters(in: .whitespaces)
            }
            if data.weeklyResetTime == nil, allResets.count > 1 {
                data.weeklyResetTime = allResets[1].trimmingCharacters(in: .whitespaces)
            }
        }

        return data
    }

    // MARK: - Regex Helpers

    /// Return the first capture group from a regex match
    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    /// Return all first capture groups from a regex
    private static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    /// Extract a block of text between two regex patterns
    private static func extractBlock(from text: String, after: String, before: String) -> String? {
        guard let afterRegex = try? NSRegularExpression(pattern: after),
              let afterMatch = afterRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        let startIdx = text.index(text.startIndex, offsetBy: afterMatch.range.location)

        if let beforeRegex = try? NSRegularExpression(pattern: before) {
            let searchRange = NSRange(startIdx..., in: text)
            // Find first match after the "after" pattern
            let beforeMatches = beforeRegex.matches(in: text, range: searchRange)
            // Use the first match that comes after the "after" match
            for m in beforeMatches {
                if m.range.location > afterMatch.range.location + afterMatch.range.length {
                    let endIdx = text.index(text.startIndex, offsetBy: m.range.location)
                    return String(text[startIdx..<endIdx])
                }
            }
        }

        // No "before" found — return everything after
        return String(text[startIdx...])
    }

    /// Extract reset time from a text block
    private static func extractReset(from block: String) -> String? {
        let pattern = "Rese[t ]?s?\\s+(.+?)(?=\\s{2,}|Curren|Extra|Esc|\\n|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
              let range = Range(match.range(at: 1), in: block) else {
            return nil
        }
        let result = String(block[range]).trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? nil : result
    }

    // MARK: - ANSI Stripping

    /// Strip ANSI escape codes and terminal control sequences from output.
    static func stripAnsiCodes(_ text: String) -> String {
        var result = text

        // First pass: Replace cursor-right movements with spaces
        if let cursorRight = try? NSRegularExpression(pattern: "\u{1b}\\[(\\d*)C") {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = cursorRight.matches(in: result, range: nsRange).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: result) else { continue }
                let countStr: String
                if let countRange = Range(match.range(at: 1), in: result) {
                    countStr = String(result[countRange])
                } else {
                    countStr = ""
                }
                let count = Int(countStr) ?? 1
                let replacement = String(repeating: " ", count: count)
                result.replaceSubrange(fullRange, with: replacement)
            }
        }

        // Second pass: Remove all other escape sequences
        let patterns = [
            "\u{1b}\\[[0-9;?]*[A-BD-Za-z]",
            "\u{1b}\\][^\u{07}\u{1b}]*[\u{07}]",
            "\u{1b}\\][^\u{1b}]*\u{1b}\\\\",
            "\u{1b}[()][A-Z0-9]",
            "\u{1b}[=>NOMDEHcn78]",
            "\\r",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Strip remaining control characters except newline and tab
        result = result.unicodeScalars.filter { scalar in
            scalar == "\n" || scalar == "\t" || scalar.value >= 0x20
        }.map { String($0) }.joined()

        return result
    }
}
