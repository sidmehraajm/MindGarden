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
        do {
            let settingsManager: SettingsManager = try DependencyContainer.shared.resolve()
            applyBlockingRules(
                apps: settingsManager.selectedApps,
                websites: settingsManager.selectedWebsites
            )
        } catch {
            print("Failed to resolve SettingsManager: \(error)")
        }
    }
}

// MARK: - Notification Names
// Removed duplicate declaration of deviceActivityMonitorDidChange 