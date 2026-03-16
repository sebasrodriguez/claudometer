import Foundation

struct UsageParser {
    /// Parse the raw output from Claude's /usage command into structured data.
    ///
    /// Known output format (as of Claude Code v2.1.76):
    /// ```
    ///   Current session
    ///   ██                                                 4% used
    ///   Resets 7pm (America/Montevideo)
    ///
    ///   Current week (all models)
    ///   ███████▌                                           15% used
    ///   Resets Mar 20 at 2:59am (America/Montevideo)
    ///
    ///   Current week (Sonnet only)
    ///                                                      0% used
    /// ```
    static func parse(_ rawOutput: String) -> UsageData {
        let cleaned = stripAnsiCodes(rawOutput)
        var data = UsageData()
        data.rawOutput = cleaned

        let lines = cleaned.components(separatedBy: .newlines)

        enum Section {
            case none, session, weeklyAll, weeklySonnet, extraUsage
        }
        var currentSection: Section = .none

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()

            // Detect section headers — use regex to tolerate mangled characters from ANSI stripping
            if matchesLoosely(lower, "current session") || matchesLoosely(lower, "curren.*session") {
                currentSection = .session
                continue
            } else if matchesLoosely(lower, "current week") && lower.contains("all model") {
                currentSection = .weeklyAll
                continue
            } else if matchesLoosely(lower, "current week") && lower.contains("sonnet") {
                currentSection = .weeklySonnet
                continue
            } else if lower.contains("extra usage") {
                currentSection = .extraUsage
                continue
            }

            // Look for "X% used" pattern
            if let pct = extractPercentUsed(from: trimmed) {
                switch currentSection {
                case .session:
                    data.sessionUsagePercent = pct
                case .weeklyAll:
                    data.weeklyUsagePercent = pct
                case .weeklySonnet:
                    data.weeklySonnetPercent = pct
                default:
                    if data.sessionUsagePercent == nil {
                        data.sessionUsagePercent = pct
                    } else if data.weeklyUsagePercent == nil {
                        data.weeklyUsagePercent = pct
                    }
                }
            }

            // Look for "Resets ..." pattern — tolerant of mangled text from ANSI stripping
            // Match "Rese" followed by optional mangled chars then a time-like pattern
            if let resetText = extractResetText(from: trimmed) {
                switch currentSection {
                case .session:
                    if data.sessionResetTime == nil { data.sessionResetTime = resetText }
                case .weeklyAll:
                    if data.weeklyResetTime == nil { data.weeklyResetTime = resetText }
                case .weeklySonnet:
                    break
                default:
                    if data.sessionResetTime == nil {
                        data.sessionResetTime = resetText
                    } else if data.weeklyResetTime == nil {
                        data.weeklyResetTime = resetText
                    }
                }
            }
        }

        return data
    }

    /// Extract percentage from "X% used" pattern
    private static func extractPercentUsed(from line: String) -> Double? {
        let pattern = "(\\d+\\.?\\d*)%\\s*used"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Double(line[range])
    }

    /// Loose string matching that tolerates single-character corruption from ANSI stripping.
    /// Inserts ".?" between each character of the pattern to allow for missing/extra chars.
    private static func matchesLoosely(_ text: String, _ keyword: String) -> Bool {
        // If keyword contains regex metacharacters like .*, use it directly
        if keyword.contains(".*") || keyword.contains(".?") {
            return (try? NSRegularExpression(pattern: keyword))
                .flatMap { $0.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) } != nil
        }
        // Otherwise, create a loose pattern: insert .? between chars
        let loosePattern = keyword.map { String($0) }.joined(separator: ".?")
        return (try? NSRegularExpression(pattern: loosePattern))
            .flatMap { $0.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) } != nil
    }

    /// Extract reset time text. Tolerant of mangled characters from ANSI stripping.
    /// Looks for patterns like "Resets 7pm (...)" or "Rese s Mar 20 at 3am (...)"
    private static func extractResetText(from line: String) -> String? {
        // Pattern: "Rese" + optional chars + space + time info with optional timezone in parens
        // The "t" and "s" in "Resets" may be mangled, so we match loosely
        let pattern = "Rese[t ]?s?\\s+(.+?)\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let text = String(line[range]).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    /// Strip ANSI escape codes and terminal control sequences from output.
    /// Handles CSI sequences, cursor movement, DEC private modes, OSC, etc.
    static func stripAnsiCodes(_ text: String) -> String {
        var result = text

        // First pass: Replace cursor-right movements (ESC[NC or ESC[1C) with spaces
        // These are used by TUIs to add spacing between elements
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
            // CSI sequences (except cursor-right which we already handled)
            "\u{1b}\\[[0-9;?]*[A-BD-Za-z]",
            // OSC sequences
            "\u{1b}\\][^\u{07}\u{1b}]*[\u{07}]",
            "\u{1b}\\][^\u{1b}]*\u{1b}\\\\",
            // Character set selection
            "\u{1b}[()][A-Z0-9]",
            // Simple escape sequences
            "\u{1b}[=>NOMDEHcn78]",
            // Carriage return
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
