import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine

@MainActor
class BlockingManager: ObservableObject {
    private let store = ManagedSettingsStore()
    private let center = AuthorizationCenter.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Start monitoring for device activity changes
        NotificationCenter.default.publisher(for: .deviceActivityMonitorDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reapplyBlockingRules()
                }
            }
            .store(in: &cancellables)
    }
    
    func requestAuthorization() async throws {
        try await center.requestAuthorization(for: .individual)
    }
    
    func applyBlockingRules(apps: Set<String>, websites: Set<String>) {
        // Clear existing rules
        store.clearAllSettings()
        
        // Set up application blocking
        // Note: This is a placeholder. Actual implementation depends on FamilyControls API
        // store.application.blockedApplications = apps // Commented out due to API mismatch
        
        // Set up website blocking
        // Note: This is a placeholder. Actual implementation depends on FamilyControls API
        // store.webDomain.blockedWebDomains = websites // Commented out due to API mismatch
        
        // Enable blocking
        store.shield.applicationCategories = .all()
        store.shield.webDomainCategories = .all()
    }
    
    func removeBlockingRules() {
        store.clearAllSettings()
    }
    
    private func reapplyBlockingRules() {
        guard let settingsManager = try? DependencyContainer.shared.resolve(SettingsManager.self) else { return }
        applyBlockingRules(
            apps: settingsManager.selectedApps,
            websites: settingsManager.selectedWebsites
        )
    }
}

// MARK: - Notification Names
// Removed duplicate declaration of deviceActivityMonitorDidChange 