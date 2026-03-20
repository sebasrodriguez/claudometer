import Foundation

/// Polls Codex usage by making a minimal API call to the Codex backend
/// and reading rate limit headers from the response.
final class CodexPoller: Sendable {

    struct RateLimitHeaders {
        var planType: String?
        var primaryUsedPercent: Double?
        var secondaryUsedPercent: Double?
        var primaryWindowMinutes: Int?
        var secondaryWindowMinutes: Int?
        var primaryResetAt: Date?
        var secondaryResetAt: Date?
    }

    func pollUsage() async throws -> RateLimitHeaders {
        let token = try loadAccessToken()
        return try await fetchRateLimits(accessToken: token)
    }

    private func fetchRateLimits(accessToken: String) async throws -> RateLimitHeaders {
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/codex/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Minimal request — uses gpt-5.4 with minimal output to trigger rate limit headers
        let body: [String: Any] = [
            "model": "gpt-5-codex-mini",
            "instructions": "reply ok",
            "input": [["role": "user", "content": "hi"]],
            "store": false,
            "stream": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PollerError.noOutput
        }

        // Headers are available immediately; consume a few lines then stop
        var lineCount = 0
        for try await _ in bytes.lines {
            lineCount += 1
            if lineCount >= 3 { break }
        }

        // Write debug info
        let hdrs = httpResponse.allHeaderFields
        let debugInfo = hdrs.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        try? "HTTP \(httpResponse.statusCode)\n\(debugInfo)".write(toFile: "/tmp/codex-headers-debug.txt", atomically: true, encoding: .utf8)

        return parseHeaders(hdrs)
    }

    private func parseHeaders(_ headers: [AnyHashable: Any]) -> RateLimitHeaders {
        // Normalize to lowercase keys for reliable lookup
        var normalized: [String: String] = [:]
        for (key, value) in headers {
            normalized["\(key)".lowercased()] = "\(value)"
        }

        var result = RateLimitHeaders()
        result.planType = normalized["x-codex-plan-type"]
        if let s = normalized["x-codex-primary-used-percent"] { result.primaryUsedPercent = Double(s) }
        if let s = normalized["x-codex-secondary-used-percent"] { result.secondaryUsedPercent = Double(s) }
        if let s = normalized["x-codex-primary-window-minutes"] { result.primaryWindowMinutes = Int(s) }
        if let s = normalized["x-codex-secondary-window-minutes"] { result.secondaryWindowMinutes = Int(s) }
        if let s = normalized["x-codex-primary-reset-at"], let ts = Double(s) {
            result.primaryResetAt = Date(timeIntervalSince1970: ts)
        }
        if let s = normalized["x-codex-secondary-reset-at"], let ts = Double(s) {
            result.secondaryResetAt = Date(timeIntervalSince1970: ts)
        }
        return result
    }

    private func loadAccessToken() throws -> String {
        let authPath = NSHomeDirectory() + "/.codex/auth.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: authPath))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let tokens = json?["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String else {
            throw PollerError.claudeNotFound
        }
        return token
    }
}
