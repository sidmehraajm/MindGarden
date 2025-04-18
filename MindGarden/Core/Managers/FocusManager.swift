import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine

@MainActor
class FocusManager: ObservableObject {
    static let shared = FocusManager()
    
    @Published private(set) var currentSession: FocusSession?
    @Published private(set) var isActive = false
    @Published private(set) var remainingTime: TimeInterval = 0
    @Published private(set) var totalFocusTime: TimeInterval = 0
    
    private let store = ManagedSettingsStore()
    private let center = AuthorizationCenter.shared
    private var blockingManager: BlockingManager?
    private var settingsManager: SettingsManager?
    private var timer: Timer?
    private var gracePeriodTimer: Timer?
    private var isInGracePeriod = false
    private var emergencyPassesUsed = 0
    private let maxEmergencyPasses = 1
    private var lastEmergencyPassDate: Date?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // We'll set up dependencies after they've been registered
        setupMonitoring()
    }
    
    func setupDependencies() {
        do {
            self.blockingManager = try DependencyContainer.shared.resolve()
            self.settingsManager = try DependencyContainer.shared.resolve()
        } catch {
            print("Failed to resolve dependencies: \(error)")
        }
    }
    
    private func setupMonitoring() {
        // Start monitoring for device activity changes
        NotificationCenter.default.publisher(for: .deviceActivityMonitorDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reapplyBlockingRules()
                }
            }
            .store(in: &cancellables)
    }
    
    enum FocusTier: Int, CaseIterable {
        case low = 5
        case medium = 15
        case high = 30
        case deep = 60
        
        var duration: TimeInterval {
            TimeInterval(self.rawValue * 60)
        }
        
        var gracePeriod: TimeInterval {
            switch self {
            case .low: return 30
            case .medium: return 15
            case .high: return 5
            case .deep: return 0
            }
        }
    }
    
    struct FocusSession {
        let tier: FocusTier
        let startTime: Date
        let endTime: Date
        let lastEmergencyPassDate: Date?
        var overrideAttempts: Int = 0
        
        var isDeepFocus: Bool { tier == .deep }
        var emergencyPassAvailable: Bool {
            guard tier == .deep else { return false }
            guard let lastPassDate = lastEmergencyPassDate else { return true }
            return Calendar.current.isDateInThisWeek(lastPassDate)
        }
    }
    
    enum FocusError: Error {
        case noActiveSession
        case authorizationFailed
        case blockingFailed
        case missingDependencies
    }
    
    func requestAuthorization() async throws {
        try await center.requestAuthorization(for: .individual)
    }
    
    func startSession(tier: FocusTier) async {
        let session = FocusSession(
            tier: tier,
            startTime: Date(),
            endTime: Date().addingTimeInterval(tier.duration),
            lastEmergencyPassDate: lastEmergencyPassDate
        )
        
        currentSession = session
        isActive = true
        remainingTime = tier.duration
        
        if tier.gracePeriod > 0 {
            startGracePeriod(duration: tier.gracePeriod)
        } else {
            applyBlockingRules()
        }
        
        startTimer()
        if tier == .deep {
            startDeepFocusMonitoring()
        }
    }
    
    func stopSession() async throws {
        guard let session = currentSession else {
            throw FocusError.noActiveSession
        }
        
        let duration = Date().timeIntervalSince(session.startTime)
        totalFocusTime += duration
        
        // Update daily stats
        guard let settingsManager = settingsManager else {
            throw FocusError.missingDependencies
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var analytics = settingsManager.analytics
        var dailyStats = analytics.dailyStats[today] ?? DailyStats()
        dailyStats.focusTime += duration
        dailyStats.completedSessions += 1
        dailyStats.overrideAttempts += session.overrideAttempts
        analytics.dailyStats[today] = dailyStats
        settingsManager.analytics = analytics
        
        currentSession = nil
        isActive = false
        remainingTime = 0
        timer?.invalidate()
        gracePeriodTimer?.invalidate()
        removeBlockingRules()
        
        NotificationCenter.default.post(name: .focusSessionDidEnd, object: nil)
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let session = self.currentSession else { return }
                
                let remaining = session.endTime.timeIntervalSince(Date())
                if remaining <= 0 {
                    try? await self.stopSession()
                } else {
                    self.remainingTime = remaining
                }
            }
        }
    }
    
    private func startGracePeriod(duration: TimeInterval) {
        isInGracePeriod = true
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isInGracePeriod = false
                self?.applyBlockingRules()
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
    
    func requestEmergencyPass() -> Bool {
        guard let session = currentSession,
              session.isDeepFocus,
              session.emergencyPassAvailable,
              emergencyPassesUsed < maxEmergencyPasses else {
            return false
        }
        
        emergencyPassesUsed += 1
        lastEmergencyPassDate = Date()
        Task {
            try? await stopSession()
        }
        return true
    }
    
    private func startDeepFocusMonitoring() {
        // Monitor for permission changes
        NotificationCenter.default.publisher(for: .deviceActivityMonitorDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reapplyDeepFocusRestrictions()
                }
            }
            .store(in: &cancellables)
    }
    
    func reapplyDeepFocusRestrictions() {
        guard let session = currentSession, session.isDeepFocus else { return }
        applyBlockingRules()
    }
    
    private func reapplyBlockingRules() {
        guard isActive else { return }
        applyBlockingRules()
    }
}

// MARK: - Calendar Extension
extension Calendar {
    func isDateInThisWeek(_ date: Date) -> Bool {
        let currentWeek = component(.weekOfYear, from: Date())
        let dateWeek = component(.weekOfYear, from: date)
        return currentWeek == dateWeek
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let deviceActivityMonitorDidChange = Notification.Name("deviceActivityMonitorDidChange")
    static let focusSessionDidEnd = Notification.Name("focusSessionDidEnd")
} 