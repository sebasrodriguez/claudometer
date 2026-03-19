import SwiftUI

/// A single usage metric reported by a provider.
struct UsageTier: Identifiable, Codable {
    let id: String
    let label: String
    var percent: Double
    var resetTime: String?
    var colorName: String?

    var resolvedColor: Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        default: return .green
        }
    }
}

/// Result of a single provider poll.
struct ProviderUsageData {
    var tiers: [UsageTier]
    var rawOutput: String?
}

/// Identifies a provider type.
enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case claude = "claude"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        }
    }

    var shortCode: String {
        switch self {
        case .claude: return "CL"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "brain.head.profile"
        }
    }
}
