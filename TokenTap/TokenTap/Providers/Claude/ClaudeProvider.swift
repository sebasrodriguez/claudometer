import Foundation

/// Claude Code usage provider. Reads usage data from the Anthropic
/// OAuth usage API using the token stored in macOS Keychain.
final class ClaudeProvider: UsageProvider, Sendable {
    static let kind: ProviderKind = .claude

    func poll() async throws -> ProviderUsageData {
        let poller = ClaudePoller()
        let response = try await poller.pollUsage()
        return ClaudeParser.parse(response)
    }
}
