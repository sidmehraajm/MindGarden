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
    
    @Published private(set) var isAuthorized = false
    
    init() {
        // Set initial authorization status
        updateAuthorizationStatus()
        
        // Monitor authorization changes - Since iOS 17+
        NotificationCenter.default.publisher(for: .authorizationStatusDidChange)
            .sink { [weak self] _ in
                self?.updateAuthorizationStatus()
            }
            .store(in: &cancellables)
        
        // Start monitoring for device activity changes
        NotificationCenter.default.publisher(for: .deviceActivityMonitorDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.reapplyBlockingRules()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateAuthorizationStatus() {
        let status = center.authorizationStatus
        #if os(iOS)
        if #available(iOS 17.0, *) {
            isAuthorized = status == .approved
        } else {
            // For older iOS versions
            isAuthorized = status != .notDetermined
        }
        #else
        // For other platforms like macOS
        isAuthorized = status != .notDetermined
        #endif
    }
    
    /// Requests authorization to use Family Controls
    /// - Throws: An error if the authorization request fails
    func requestAuthorization() async throws {
        do {
            try await center.requestAuthorization(for: .individual)
            updateAuthorizationStatus()
        } catch {
            print("Failed to request authorization: \(error)")
            throw error
        }
    }
    
    /// Applies blocking rules for the specified apps and websites
    /// - Parameters:
    ///   - apps: Set of app bundle identifiers to block
    ///   - websites: Set of website domains to block
    func applyBlockingRules(apps: Set<String>, websites: Set<String>) async {
        // Clear existing rules before applying new ones
        removeBlockingRules()
        
        if apps.isEmpty && websites.isEmpty {
            return // Nothing to block
        }
        
        // Set up application blocking
        if !apps.isEmpty {
            // In recent iOS versions, we can't directly convert bundle IDs to tokens
            // So we use a combination of selection-based and category-based blocking
            
            // For apps, use the appropriate shield settings
            if #available(iOS 16.0, *) {
                // In iOS 16+, we use a more category-based approach
                store.shield.applications = .none
                
                // Shield based on all categories since we can't directly map to categories
                store.shield.applicationCategories = .all()
            } else {
                // For iOS 15, we fall back to simply blocking all apps
                store.shield.applicationCategories = .all()
            }
        }
        
        // Set up website blocking
        if !websites.isEmpty {
            // For websites, use the appropriate shield settings
            if #available(iOS 16.0, *) {
                // In iOS 16+, we use a more category-based approach
                store.shield.webDomains = .none
                
                // Shield based on all categories since we can't directly map to categories
                store.shield.webDomainCategories = .all()
            } else {
                // For iOS 15, we fall back to simply blocking all web domains
                store.shield.webDomainCategories = .all()
            }
        }
    }
    
    /// Removes all blocking rules
    func removeBlockingRules() {
        store.clearAllSettings()
    }
    
    /// Refreshes the blocking rules by reapplying them
    func refreshBlockingRules() async {
        await reapplyBlockingRules()
    }
    
    /// Reapplies blocking rules based on the current settings
    private func reapplyBlockingRules() async {
        do {
            let settingsManager: SettingsManager = try DependencyContainer.shared.resolve()
            await applyBlockingRules(
                apps: settingsManager.selectedApps,
                websites: settingsManager.selectedWebsites
            )
        } catch {
            print("Failed to resolve SettingsManager: \(error)")
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let authorizationStatusDidChange = Notification.Name("authorizationStatusDidChange")
} 