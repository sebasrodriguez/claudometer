import Foundation

/// OpenAI Codex CLI usage provider. Spawns an ephemeral Codex CLI process,
/// sends /status, and parses the output into a UsageTier.
final class CodexProvider: UsageProvider, Sendable {
    static let kind: ProviderKind = .codex

    var binaryPath: String {
        UserDefaults.standard.string(forKey: "provider.codex.binaryPath") ?? ""
    }

    func poll() async throws -> ProviderUsageData {
        let poller = CodexPoller()
        let path = binaryPath.isEmpty ? nil : binaryPath
        let rawText = try await poller.pollUsage(codexPath: path)
        return CodexParser.parse(rawText)
    }
}
