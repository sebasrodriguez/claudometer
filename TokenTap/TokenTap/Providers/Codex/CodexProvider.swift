import Foundation

/// OpenAI Codex usage provider. Makes a minimal API call to the Codex backend
/// and reads rate limit data from response headers.
final class CodexProvider: UsageProvider, Sendable {
    static let kind: ProviderKind = .codex

    func poll() async throws -> ProviderUsageData {
        let poller = CodexPoller()
        let headers = try await poller.pollUsage()
        return CodexParser.parse(headers)
    }
}
