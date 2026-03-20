import Foundation

/// Polls Claude usage via the OAuth usage API endpoint.
/// Reads the OAuth token from macOS Keychain and makes a GET request
/// to api.anthropic.com/api/oauth/usage.
final class ClaudePoller: Sendable {

    struct UsageResponse: Decodable {
        struct Tier: Decodable {
            let utilization: Double
            let resets_at: String
        }

        struct ExtraUsage: Decodable {
            let is_enabled: Bool
            let utilization: Double?
        }

        let five_hour: Tier?
        let seven_day: Tier?
        let seven_day_sonnet: Tier?
        let seven_day_opus: Tier?
        let extra_usage: ExtraUsage?
    }

    func pollUsage() async throws -> UsageResponse {
        let token = try loadAccessToken()

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PollerError.apiError(statusCode)
        }

        return try JSONDecoder().decode(UsageResponse.self, from: data)
    }

    private func loadAccessToken() throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PollerError.authNotFound
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = jsonStr.data(using: .utf8),
              let creds = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let oauth = creds["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            throw PollerError.authNotFound
        }

        return token
    }
}
