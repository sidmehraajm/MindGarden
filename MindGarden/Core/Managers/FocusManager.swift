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
        
        // Calculate remaining seconds
        var remainingSeconds: TimeInterval {
            return endTime.timeIntervalSince(Date())
        }
    }
    
    @Published var currentSession: FocusSession?
    @Published var isActive: Bool = false
    @Published var isInGracePeriod: Bool = false
    @Published var breakEndTime: Date?
    @Published var breakStartTime: Date?
    @Published var gracePeriodEndTime: Date?
    
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
    private var notificationSubscription: AnyCancellable?
    
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
                // Request authorization for FamilyControls
                try await blockingManager.requestAuthorization()
                
                // Initialize focus stats
                totalFocusTime = settingsManager.analytics.totalFocusTime
                totalFocusMinutesToday = Int(settingsManager.analytics.dailyStats[Calendar.current.startOfDay(for: Date())]?.focusTime ?? 0) / 60
                lastEmergencyPassDate = settingsManager.analytics.lastEmergencyPassDate
                
                // Start monitoring system activity
                startDeepFocusMonitoring()
                
                isActive = true
                
                // Apply blocking rules immediately
                await applyBlockingRules()
            } catch {
                print("Failed to initialize FocusManager: \(error)")
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        gracePeriodTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
        notificationSubscription?.cancel()
    }
    
    func startBreak(duration: TimeInterval) async {
        isInGracePeriod = true
        let now = Date()
        breakStartTime = now
        breakEndTime = now.addingTimeInterval(duration)
        
        await removeBlockingRules()
        
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isInGracePeriod = false
                self?.breakEndTime = nil
                self?.breakStartTime = nil
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
        breakStartTime = nil
        gracePeriodEndTime = nil
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
        
        await startBreak(duration: 3600) // 1 hour
        
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
        do {
            let blockingManager: BlockingManager = try DependencyContainer.shared.resolve()
            let settingsManager: SettingsManager = try DependencyContainer.shared.resolve()
            
            await blockingManager.applyBlockingRules(
                apps: settingsManager.selectedApps,
                websites: settingsManager.selectedWebsites
            )
        } catch {
            print("Error applying blocking rules: \(error)")
        }
    }
    
    func removeBlockingRules() async {
        do {
            let blockingManager: BlockingManager = try DependencyContainer.shared.resolve()
            blockingManager.removeBlockingRules()
        } catch {
            print("Error removing blocking rules: \(error)")
        }
    }
    
    private func startDeepFocusMonitoring() {
        // Start monitoring for device activity changes
        notificationSubscription = NotificationCenter.default.publisher(for: .deviceActivityMonitorDidChange)
            .sink { [weak self] _ in
                guard let self = self, self.isActive, !self.isInGracePeriod else { return }
                
                // Reapply blocking rules when device activity changes
                Task {
                    await self.refreshBlockingRules()
                }
            }
    }
    
    private func stopDeepFocusMonitoring() {
        notificationSubscription?.cancel()
        notificationSubscription = nil
    }
    
    private func reapplyBlockingRules() async {
        guard isActive, !isInGracePeriod else { return }
        await applyBlockingRules()
    }
    
    // Public method to refresh blocking rules from outside
    func refreshBlockingRules() async {
        do {
            let blockingManager: BlockingManager = try DependencyContainer.shared.resolve()
            await blockingManager.refreshBlockingRules()
        } catch {
            print("Error refreshing blocking rules: \(error)")
        }
    }
    
    func startFocusSession(duration: TimeInterval) async {
        guard !isActive else { return }
        
        let tier = determineTierFromDuration(duration)
        let session = FocusSession(
            tier: tier,
            startTime: Date(),
            duration: duration,
            isDeepFocus: tier == .deep
        )
        
        // Apply blocking rules
        Task {
            await applyBlockingRules()
        }
        
        self.currentSession = session
        self.isActive = true
        
        // Cancel any existing timer
        timer?.invalidate()
        
        // Schedule the timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionStatus()
        }
        
        // Start monitoring for device activity
        startDeepFocusMonitoring()
        
        // Track the session start for analytics
        trackSessionStart()
    }
    
    private func determineTierFromDuration(_ duration: TimeInterval) -> FocusTier {
        let minutes = Int(duration / 60)
        
        if minutes <= FocusTier.low.rawValue {
            return .low
        } else if minutes <= FocusTier.medium.rawValue {
            return .medium
        } else if minutes <= FocusTier.high.rawValue {
            return .high
        } else {
            return .deep
        }
    }
    
    private func updateSessionStatus() {
        guard let session = currentSession else { return }
        
        // Update the remaining time
        if session.remainingSeconds <= 0 {
            // Session complete
            endFocusSession()
        }
    }
    
    private func trackSessionStart() {
        // Update analytics for session start
        let today = Calendar.current.startOfDay(for: Date())
        var dailyStats = settingsManager.analytics.dailyStats[today] ?? DailyStats()
        settingsManager.analytics.dailyStats[today] = dailyStats
    }
    
    private func trackCompletedSession() {
        guard let session = currentSession else { return }
        
        // Update analytics for completed session
        let sessionDuration = session.endTime.timeIntervalSince(session.startTime)
        
        // Update total focus time
        settingsManager.analytics.totalFocusTime += sessionDuration
        
        // Update daily stats
        let today = Calendar.current.startOfDay(for: Date())
        var dailyStats = settingsManager.analytics.dailyStats[today] ?? DailyStats()
        dailyStats.focusTime += sessionDuration
        dailyStats.completedSessions += 1
        settingsManager.analytics.dailyStats[today] = dailyStats
        
        // Update the observable properties
        totalFocusTime = settingsManager.analytics.totalFocusTime
        totalFocusMinutesToday = Int(dailyStats.focusTime / 60)
    }
    
    func endFocusSession() {
        guard isActive else { return }
        
        // Only track completed sessions if they weren't ended early
        if let session = currentSession, session.remainingSeconds <= 0 {
            trackCompletedSession()
        }
        
        isActive = false
        currentSession = nil
        
        // Stop the timer
        timer?.invalidate()
        timer = nil
        
        // Remove blocking rules
        Task {
            await removeBlockingRules()
        }
        
        // Stop monitoring
        stopDeepFocusMonitoring()
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