import Foundation
import SwiftUI

struct UsageData {
    var sessionUsagePercent: Double?
    var weeklyUsagePercent: Double?
    var weeklySonnetPercent: Double?
    var sessionResetTime: String?
    var weeklyResetTime: String?
    var rawOutput: String?
}

@MainActor
class UsageModel: ObservableObject {
    @Published var sessionUsagePercent: Double?
    @Published var weeklyUsagePercent: Double?
    @Published var weeklySonnetPercent: Double?
    @Published var sessionResetTime: String?
    @Published var weeklyResetTime: String?
    @Published var lastUpdated: Date?
    @Published var isPolling: Bool = false
    @Published var rawOutput: String?
    @Published var error: String?

    @Published var refreshInterval: Double = UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 300 {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }
    @Published var warningThreshold: Double = UserDefaults.standard.object(forKey: "warningThreshold") as? Double ?? 80 {
        didSet { UserDefaults.standard.set(warningThreshold, forKey: "warningThreshold") }
    }
    @Published var criticalThreshold: Double = UserDefaults.standard.object(forKey: "criticalThreshold") as? Double ?? 90 {
        didSet { UserDefaults.standard.set(criticalThreshold, forKey: "criticalThreshold") }
    }
    @Published var claudeBinaryPath: String = UserDefaults.standard.string(forKey: "claudeBinaryPath") ?? "" {
        didSet { UserDefaults.standard.set(claudeBinaryPath, forKey: "claudeBinaryPath") }
    }
    @Published var notificationsEnabled: Bool = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var displayMode: MenuBarDisplayMode = MenuBarDisplayMode(rawValue: UserDefaults.standard.string(forKey: "displayMode") ?? "") ?? .barAndText {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode") }
    }

    private var timer: Timer?
    private var hasNotifiedWarning = false
    private var hasNotifiedCritical = false

    // MARK: - Cache

    private static let cacheKey = "cachedUsageData"

    init() {
        loadCache()
    }

    private func loadCache() {
        let d = UserDefaults.standard
        guard d.object(forKey: "\(Self.cacheKey).sessionPct") != nil else { return }

        sessionUsagePercent = d.object(forKey: "\(Self.cacheKey).sessionPct") as? Double
        weeklyUsagePercent = d.object(forKey: "\(Self.cacheKey).weeklyPct") as? Double
        weeklySonnetPercent = d.object(forKey: "\(Self.cacheKey).sonnetPct") as? Double
        sessionResetTime = d.string(forKey: "\(Self.cacheKey).sessionReset")
        weeklyResetTime = d.string(forKey: "\(Self.cacheKey).weeklyReset")
        if let ts = d.object(forKey: "\(Self.cacheKey).lastUpdated") as? Double {
            lastUpdated = Date(timeIntervalSince1970: ts)
        }
    }

    private func saveCache() {
        let d = UserDefaults.standard
        if let v = sessionUsagePercent { d.set(v, forKey: "\(Self.cacheKey).sessionPct") }
        if let v = weeklyUsagePercent { d.set(v, forKey: "\(Self.cacheKey).weeklyPct") }
        if let v = weeklySonnetPercent { d.set(v, forKey: "\(Self.cacheKey).sonnetPct") }
        d.set(sessionResetTime, forKey: "\(Self.cacheKey).sessionReset")
        d.set(weeklyResetTime, forKey: "\(Self.cacheKey).weeklyReset")
        d.set(Date().timeIntervalSince1970, forKey: "\(Self.cacheKey).lastUpdated")
    }

    // MARK: - Computed

    var statusColor: Color {
        guard let pct = sessionUsagePercent else { return .secondary }
        if pct >= criticalThreshold { return .red }
        if pct >= warningThreshold { return .orange }
        return .green
    }

    var weeklyStatusColor: Color {
        guard let pct = weeklyUsagePercent else { return .secondary }
        if pct >= criticalThreshold { return .red }
        if pct >= warningThreshold { return .orange }
        return .green
    }

    var menuBarText: String {
        if isPolling && sessionUsagePercent == nil {
            return "CC ..."
        }
        if let pct = sessionUsagePercent {
            return String(format: "CC %.0f%%", pct)
        }
        if error != nil {
            return "CC --"
        }
        return "CC --"
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
                let poller = UsagePoller()
                let binaryPath = claudeBinaryPath.isEmpty ? nil : claudeBinaryPath
                let rawText = try await poller.pollUsage(claudePath: binaryPath)
                let parsed = UsageParser.parse(rawText)

                await MainActor.run {
                    self.rawOutput = UsageParser.stripAnsiCodes(rawText)
                    self.sessionUsagePercent = parsed.sessionUsagePercent
                    self.weeklyUsagePercent = parsed.weeklyUsagePercent
                    self.weeklySonnetPercent = parsed.weeklySonnetPercent
                    self.sessionResetTime = parsed.sessionResetTime
                    self.weeklyResetTime = parsed.weeklyResetTime
                    self.lastUpdated = Date()
                    self.isPolling = false
                    self.error = nil
                    self.saveCache()
                    self.checkNotifications()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isPolling = false
                }
            }
        }
    }

    private func checkNotifications() {
        guard notificationsEnabled else { return }

        if let pct = sessionUsagePercent {
            if pct >= criticalThreshold && !hasNotifiedCritical {
                hasNotifiedCritical = true
                sendNotification(
                    title: "Claude Usage Critical",
                    body: String(format: "Session usage at %.0f%% — consider wrapping up", pct)
                )
            } else if pct >= warningThreshold && !hasNotifiedWarning {
                hasNotifiedWarning = true
                sendNotification(
                    title: "Claude Usage Warning",
                    body: String(format: "Session usage at %.0f%%", pct)
                )
            }

            if pct < warningThreshold {
                hasNotifiedWarning = false
                hasNotifiedCritical = false
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "display notification \"\(body)\" with title \"\(title)\""]
        try? process.run()
    }
}
