import Foundation
import SwiftUI

/// Per-provider observable state. Owns its polling timer, cache, and notification logic.
@MainActor
class ProviderState: ObservableObject, Identifiable {
    nonisolated let kind: ProviderKind
    let provider: any UsageProvider

    @Published var tiers: [UsageTier] = []
    @Published var lastUpdated: Date?
    @Published var isPolling: Bool = false
    @Published var rawOutput: String?
    @Published var error: String?

    @Published var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: key("refreshInterval")) }
    }

    nonisolated var id: String { kind.id }

    private var timer: Timer?
    private var hasNotifiedWarning = false
    private var hasNotifiedCritical = false

    init(kind: ProviderKind, provider: any UsageProvider) {
        self.kind = kind
        self.provider = provider
        self.refreshInterval = UserDefaults.standard.object(forKey: "provider.\(kind.rawValue).refreshInterval") as? Double ?? 300
        loadCache()
    }

    /// Primary tier (first one) — used for menu bar display.
    var primaryPercent: Double? { tiers.first?.percent }

    var menuBarText: String {
        if let pct = primaryPercent {
            return String(format: "%@ %.0f%%", kind.shortCode, pct)
        }
        if isPolling && tiers.isEmpty {
            return "\(kind.shortCode) ..."
        }
        return "\(kind.shortCode) --"
    }

    var statusColor: Color {
        guard let pct = primaryPercent else { return .secondary }
        if pct >= 90 { return .red }
        if pct >= 70 { return .orange }
        return .green
    }

    // MARK: - Polling

    func startPolling() {
        guard timer == nil else { return }
        refreshNow()
        scheduleTimer()
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshNow()
            }
        }
    }

    func refreshNow() {
        guard !isPolling else { return }
        isPolling = true
        error = nil

        Task {
            do {
                let result = try await provider.poll()

                await MainActor.run {
                    if !result.tiers.isEmpty {
                        self.tiers = result.tiers
                        self.rawOutput = result.rawOutput
                        self.lastUpdated = Date()
                        self.saveCache()
                    }
                    self.isPolling = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isPolling = false
                }
            }
        }
    }

    // MARK: - Cache

    private func key(_ field: String) -> String {
        "provider.\(kind.rawValue).\(field)"
    }

    private func loadCache() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: key("cache.tiers")),
           let cached = try? JSONDecoder().decode([UsageTier].self, from: data) {
            tiers = cached
        }
        if let ts = d.object(forKey: key("cache.lastUpdated")) as? Double {
            lastUpdated = Date(timeIntervalSince1970: ts)
        }
    }

    private func saveCache() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(tiers) {
            d.set(data, forKey: key("cache.tiers"))
        }
        d.set(Date().timeIntervalSince1970, forKey: key("cache.lastUpdated"))
    }

    // MARK: - Notifications

    func checkNotifications(warningThreshold: Double, criticalThreshold: Double) {
        guard let pct = primaryPercent else { return }

        if pct >= criticalThreshold && !hasNotifiedCritical {
            hasNotifiedCritical = true
            sendNotification(
                title: "\(kind.displayName) Usage Critical",
                body: String(format: "Session usage at %.0f%% — consider wrapping up", pct)
            )
        } else if pct >= warningThreshold && !hasNotifiedWarning {
            hasNotifiedWarning = true
            sendNotification(
                title: "\(kind.displayName) Usage Warning",
                body: String(format: "Session usage at %.0f%%", pct)
            )
        }

        if pct < warningThreshold {
            hasNotifiedWarning = false
            hasNotifiedCritical = false
        }
    }

    private func sendNotification(title: String, body: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "display notification \"\(body)\" with title \"\(title)\""]
        try? process.run()
    }
}
