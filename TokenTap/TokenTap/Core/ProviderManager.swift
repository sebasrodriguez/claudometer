import Foundation
import SwiftUI
import Combine

/// Top-level state manager. Holds all provider states and global settings.
@MainActor
class ProviderManager: ObservableObject {
    @Published var providers: [ProviderState] = []
    @Published var displayedProviderIndex: Int = 0

    private var childCancellables: [AnyCancellable] = []

    @Published var displayMode: MenuBarDisplayMode = MenuBarDisplayMode(rawValue: UserDefaults.standard.string(forKey: "displayMode") ?? "") ?? .barAndText {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode") }
    }
    @Published var notificationsEnabled: Bool = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var warningThreshold: Double = UserDefaults.standard.object(forKey: "warningThreshold") as? Double ?? 80 {
        didSet { UserDefaults.standard.set(warningThreshold, forKey: "warningThreshold") }
    }
    @Published var criticalThreshold: Double = UserDefaults.standard.object(forKey: "criticalThreshold") as? Double ?? 90 {
        didSet { UserDefaults.standard.set(criticalThreshold, forKey: "criticalThreshold") }
    }
    @Published var rotationInterval: Double = UserDefaults.standard.object(forKey: "rotationInterval") as? Double ?? 10.0 {
        didSet {
            UserDefaults.standard.set(rotationInterval, forKey: "rotationInterval")
            startRotation()
        }
    }

    private var rotationTimer: Timer?

    /// The provider currently displayed in the menu bar.
    var displayedProvider: ProviderState? {
        guard !providers.isEmpty else { return nil }
        return providers[displayedProviderIndex % providers.count]
    }

    init() {
        let claude = ProviderState(kind: .claude, provider: ClaudeProvider())
        let codex = ProviderState(kind: .codex, provider: CodexProvider())
        providers = [claude, codex]

        // Set back-reference so providers can trigger notifications
        for provider in providers {
            provider.manager = self
        }

        // Forward child objectWillChange to parent so SwiftUI picks up nested updates
        for provider in providers {
            provider.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &childCancellables)
        }
    }

    func startAll() {
        for provider in providers {
            provider.startPolling()
        }
        startRotation()
    }

    func refreshAll() {
        for provider in providers {
            provider.refreshNow()
        }
    }

    private func startRotation() {
        rotationTimer?.invalidate()
        guard providers.count > 1 else {
            displayedProviderIndex = 0
            return
        }
        rotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.providers.isEmpty else { return }
                self.displayedProviderIndex = (self.displayedProviderIndex + 1) % self.providers.count
            }
        }
    }

    func checkNotifications() {
        guard notificationsEnabled else { return }
        for provider in providers {
            provider.checkNotifications(warningThreshold: warningThreshold, criticalThreshold: criticalThreshold)
        }
    }
}
