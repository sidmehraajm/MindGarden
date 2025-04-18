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
    
    func requestAuthorization() async throws {
        do {
            try await center.requestAuthorization(for: .individual)
            updateAuthorizationStatus()
        } catch {
            print("Failed to request authorization: \(error)")
            throw error
        }
    }
    
    func applyBlockingRules(apps: Set<String>, websites: Set<String>) async {
        // Clear existing rules before applying new ones
        store.clearAllSettings()
        
        if !apps.isEmpty || !websites.isEmpty {
            // Set up application blocking - using categories for now
            // In a real implementation with iOS 18+, you would use
            // specific app tokens from FamilyActivitySelection
            if !apps.isEmpty {
                store.shield.applicationCategories = .all()
            }
            
            // Set up website blocking - using categories for now
            if !websites.isEmpty {
                store.shield.webDomainCategories = .all()
            }
            
            // Enable shield for both applications and web domains
            // This will restrict access based on the categories above
            store.shield.applicationCategories = apps.isEmpty ? .none : .all()
            store.shield.webDomainCategories = websites.isEmpty ? .none : .all()
        }
    }
    
    func removeBlockingRules() {
        store.clearAllSettings()
    }
    
    func refreshBlockingRules() async {
        await reapplyBlockingRules()
    }
    
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