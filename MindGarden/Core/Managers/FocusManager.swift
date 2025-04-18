import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine
import SwiftUI

@MainActor
class FocusManager: ObservableObject {
    static let shared = FocusManager()
    
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
    
    private var blockingManager: BlockingManager?
    private var settingsManager: SettingsManager?
    private var timer: Timer?
    private var gracePeriodTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Task {
            do {
                self.blockingManager = try DependencyContainer.shared.resolve()
                self.settingsManager = try DependencyContainer.shared.resolve()
                
                try await blockingManager?.requestAuthorization()
                
                applyBlockingRules()
                
                startDeepFocusMonitoring()
                
                if let settings = settingsManager {
                    totalFocusTime = settings.analytics.totalFocusTime
                    totalFocusMinutesToday = Int(settings.analytics.dailyStats[Calendar.current.startOfDay(for: Date())]?.focusTime ?? 0) / 60
                }
                
                if let lastDate = settings.analytics.lastEmergencyPassDate {
                    lastEmergencyPassDate = lastDate
                }
                
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
    
    func startBreak(duration: TimeInterval) {
        isInGracePeriod = true
        breakEndTime = Date().addingTimeInterval(duration)
        
        removeBlockingRules()
        
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isInGracePeriod = false
                self?.breakEndTime = nil
                self?.applyBlockingRules()
                self?.updateBreakStats()
            }
        }
        
        updateBreakStats()
    }
    
    func endBreakEarly() {
        gracePeriodTimer?.invalidate()
        isInGracePeriod = false
        breakEndTime = nil
        applyBlockingRules()
    }
    
    func startSession(tier: FocusTier) async {
        startBreak(duration: TimeInterval(tier.rawValue * 60))
    }
    
    func stopSession() async throws {
        if isInGracePeriod {
            endBreakEarly()
        }
    }
    
    func requestEmergencyPass() -> Bool {
        if let lastDate = lastEmergencyPassDate, 
           Calendar.current.isDateInToday(lastDate) {
            return false
        }
        
        lastEmergencyPassDate = Date()
        
        startBreak(duration: 3600)
        
        Task {
            if let settings = settingsManager {
                settings.analytics.lastEmergencyPassDate = lastEmergencyPassDate
                settings.analytics.overrideAttempts += 1
            }
        }
        
        return true
    }
    
    private func updateBreakStats() {
        Task {
            if let settings = settingsManager {
                settings.analytics.breaksTaken += 1
                
                let today = Calendar.current.startOfDay(for: Date())
                var dailyStats = settings.analytics.dailyStats[today] ?? DailyStats()
                dailyStats.breaksTaken += 1
                settings.analytics.dailyStats[today] = dailyStats
            }
        }
    }
    
    private func applyBlockingRules() {
        guard let blockingManager = blockingManager, 
              let settingsManager = settingsManager else { return }
        
        blockingManager.applyBlockingRules(
            apps: settingsManager.selectedApps,
            websites: settingsManager.selectedWebsites
        )
    }
    
    private func removeBlockingRules() {
        blockingManager?.removeBlockingRules()
    }
    
    private func startDeepFocusMonitoring() {
        NotificationCenter.default.publisher(for: .deviceActivityMonitorDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    if let self = self, !self.isInGracePeriod {
                        self.reapplyBlockingRules()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func reapplyBlockingRules() {
        guard isActive, !isInGracePeriod else { return }
        applyBlockingRules()
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