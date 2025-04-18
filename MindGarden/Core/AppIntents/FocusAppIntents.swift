import AppIntents
import Foundation

// MARK: - Focus Duration Enum
enum FocusDuration: Int, CaseIterable, AppEnum {
    case low = 15
    case medium = 30
    case high = 60
    case deep = 120
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Focus Duration")
    }
    
    static var caseDisplayRepresentations: [FocusDuration: DisplayRepresentation] {
        [
            .low: DisplayRepresentation(title: "Low (15 min)"),
            .medium: DisplayRepresentation(title: "Medium (30 min)"),
            .high: DisplayRepresentation(title: "High (60 min)"),
            .deep: DisplayRepresentation(title: "Deep (120 min)")
        ]
    }
    
    // Map FocusDuration to FocusManager.FocusTier
    var focusTier: FocusManager.FocusTier {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .deep: return .deep
        }
    }
}

// MARK: - Start Focus Session Intent
struct StartFocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Session"
    
    @Parameter(title: "Duration")
    var duration: FocusDuration
    
    func perform() async throws -> some IntentResult {
        let focusManager = try await DependencyContainer.shared.resolve(FocusManager.self)
        
        let tier = FocusManager.FocusTier(rawValue: duration.rawValue / 60) ?? .medium
        await focusManager.startSession(tier: tier)
        
        return .result(value: "Started focus session for \(duration.rawValue) minutes")
    }
}

// MARK: - Stop Focus Session Intent
struct StopFocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Focus Session"
    
    func perform() async throws -> some IntentResult {
        let focusManager = try await DependencyContainer.shared.resolve(FocusManager.self)
        
        try await focusManager.stopSession()
        
        return .result(value: "Stopped focus session")
    }
}

// MARK: - Get Focus Stats Intent
struct GetFocusStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Focus Stats"
    
    func perform() async throws -> some IntentResult {
        let settings = try await DependencyContainer.shared.resolve(SettingsManager.self)
        let focusManager = try await DependencyContainer.shared.resolve(FocusManager.self)
        
        let totalTime = await focusManager.totalFocusTime
        let hours = Int(totalTime / 3600)
        let minutes = Int((totalTime.truncatingRemainder(dividingBy: 3600)) / 60)
        
        let overrides = await settings.analytics.overrideAttempts
        
        return .result(value: "Total focus time: \(hours)h \(minutes)m\nOverride attempts: \(overrides)")
    }
}

// MARK: - Intent Error Enum
enum IntentError: Error {
    case focusManagerError(String)
    case settingsManagerError(String)
} 