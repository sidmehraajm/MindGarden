import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine
import SwiftUI

@MainActor
class FocusManager: ObservableObject {
    static var shared = FocusManager()
    
    enum FocusTier: Int, CaseIterable {
        case low = 15
        case medium = 30
        case high = 60
        case deep = 120
    }
    
    struct FocusSession {
        var tier: FocusTier
        var startTime: Date
        var endTime: Date
        var isActive: Bool = true
        var isDeepFocus: Bool
        var emergencyPassAvailable: Bool = true
        var lastEmergencyPassDate: Date?
        
        init(tier: FocusTier, startTime: Date = Date(), duration: TimeInterval, isDeepFocus: Bool = false, lastEmergencyPassDate: Date? = nil) {
            self.tier = tier
            self.startTime = startTime
            self.endTime = startTime.addingTimeInterval(duration)
            self.isDeepFocus = isDeepFocus
            self.lastEmergencyPassDate = lastEmergencyPassDate
        }
    }
    
    @Published var currentSession: FocusSession?
    @Published var isActive: Bool = false
    @Published var isInGracePeriod: Bool = false
    @Published var breakEndTime: Date?
    
    @Published var totalFocusTime: TimeInterval = 0
    @Published var totalFocusMinutesToday: Int = 0
    
    private let maxEmergencyPasses: Int = 1
    @Published var emergencyPassesUsed: Int = 0
    @Published var lastEmergencyPassDate: Date?
    
    private var blockingManager: BlockingManager
    private var settingsManager: SettingsManager
    private var timer: Timer?
    private var gracePeriodTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Empty default initializer used by the 'shared' static property
        // The DependencyContainer will replace this instance with a properly initialized one
        self.settingsManager = SettingsManager()
        self.blockingManager = BlockingManager()
    }
    
    init(settingsManager: SettingsManager, blockingManager: BlockingManager) {
        self.settingsManager = settingsManager
        self.blockingManager = blockingManager
        
        Task {
            do {
                try await blockingManager.requestAuthorization()
                
                // Initialize focus stats
                totalFocusTime = settingsManager.analytics.totalFocusTime
                totalFocusMinutesToday = Int(settingsManager.analytics.dailyStats[Calendar.current.startOfDay(for: Date())]?.focusTime ?? 0) / 60
                lastEmergencyPassDate = settingsManager.analytics.lastEmergencyPassDate
                
                // Start monitoring system activity
                startDeepFocusMonitoring()
                
                isActive = true
            } catch {
                print("Failed to initialize FocusManager: \(error)")
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        gracePeriodTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
    
    func startBreak(duration: TimeInterval) async {
        isInGracePeriod = true
        breakEndTime = Date().addingTimeInterval(duration)
        
        await removeBlockingRules()
        
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isInGracePeriod = false
                self?.breakEndTime = nil
                await self?.applyBlockingRules()
                self?.updateBreakStats()
            }
        }
        
        updateBreakStats()
    }
    
    func endBreakEarly() async {
        gracePeriodTimer?.invalidate()
        isInGracePeriod = false
        breakEndTime = nil
        await applyBlockingRules()
    }
    
    func startSession(tier: FocusTier) async {
        await startBreak(duration: TimeInterval(tier.rawValue * 60))
    }
    
    func stopSession() async throws {
        if isInGracePeriod {
            await endBreakEarly()
        }
    }
    
    func requestEmergencyPass() async -> Bool {
        if let lastDate = lastEmergencyPassDate, 
           Calendar.current.isDateInToday(lastDate) {
            return false
        }
        
        lastEmergencyPassDate = Date()
        
        await startBreak(duration: 3600)
        
        Task {
            settingsManager.analytics.lastEmergencyPassDate = lastEmergencyPassDate
            settingsManager.analytics.overrideAttempts += 1
            
            let today = Calendar.current.startOfDay(for: Date())
            var dailyStats = settingsManager.analytics.dailyStats[today] ?? DailyStats()
            dailyStats.overrideAttempts += 1
            settingsManager.analytics.dailyStats[today] = dailyStats
        }
        
        return true
    }
    
    private func updateBreakStats() {
        Task {
            settingsManager.analytics.breaksTaken += 1
            
            let today = Calendar.current.startOfDay(for: Date())
            var dailyStats = settingsManager.analytics.dailyStats[today] ?? DailyStats()
            dailyStats.breaksTaken += 1
            settingsManager.analytics.dailyStats[today] = dailyStats
        }
    }
    
    func applyBlockingRules() async {
        await blockingManager.applyBlockingRules(
            apps: settingsManager.selectedApps,
            websites: settingsManager.selectedWebsites
        )
    }
    
    func removeBlockingRules() async {
        blockingManager.removeBlockingRules()
    }
    
    private func startDeepFocusMonitoring() {
        NotificationCenter.default.publisher(for: .deviceActivityMonitorDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    if let self = self, !self.isInGracePeriod {
                        await self.reapplyBlockingRules()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func reapplyBlockingRules() async {
        guard isActive, !isInGracePeriod else { return }
        await applyBlockingRules()
    }
    
    // Public method to refresh blocking rules from outside
    func refreshBlockingRules() async {
        await reapplyBlockingRules()
    }
    
    func startFocusSession(duration: TimeInterval) async {
        guard !isActive else { return }
        
        await startBreak(duration: duration)
    }
    
    func endFocusSession() async {
        guard isActive else { return }
        
        await removeBlockingRules()
    }
}

extension Calendar {
    func isDateInThisWeek(_ date: Date) -> Bool {
        return isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

extension Notification.Name {
    static let deviceActivityMonitorDidChange = Notification.Name("com.apple.deviceactivity.monitor.did-change")
} 