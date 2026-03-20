import Foundation

enum PollerError: LocalizedError {
    case authNotFound
    case apiError(Int)
    case noOutput
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .authNotFound:
            return "Auth credentials not found. Make sure the CLI is installed and logged in."
        case .apiError(let code):
            return "API returned HTTP \(code)."
        case .noOutput:
            return "No data received from provider."
        case .networkError(let msg):
            return "Network error: \(msg)"
        }
    }
}
