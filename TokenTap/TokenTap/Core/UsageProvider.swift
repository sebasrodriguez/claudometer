import Foundation

/// Protocol that every usage provider implements.
/// Adding a new provider = implement this protocol + add a case to ProviderKind.
protocol UsageProvider: AnyObject, Sendable {
    static var kind: ProviderKind { get }
    func poll() async throws -> ProviderUsageData
}
