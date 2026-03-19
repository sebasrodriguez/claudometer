import Foundation

/// Claude Code usage provider. Spawns an ephemeral Claude CLI process,
/// sends /usage, and parses the TUI output into UsageTiers.
final class ClaudeProvider: UsageProvider, Sendable {
    static let kind: ProviderKind = .claude

    /// Claude CLI binary path override. Empty = auto-detect.
    var binaryPath: String {
        UserDefaults.standard.string(forKey: "provider.claude.binaryPath") ?? ""
    }

    func poll() async throws -> ProviderUsageData {
        let poller = ClaudePoller()
        let path = binaryPath.isEmpty ? nil : binaryPath
        let rawText = try await poller.pollUsage(claudePath: path)
        return ClaudeParser.parse(rawText)
    }
}
