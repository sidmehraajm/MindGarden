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
    static var description = IntentDescription("Start a focus session with the specified duration")
    
    @Parameter(title: "Duration", description: "How long to focus for")
    var duration: FocusDuration
    
    func perform() async throws -> some IntentResult {
        do {
            let focusManager: FocusManager = try await DependencyContainer.shared.resolve()
            let minutes = duration.rawValue
            await focusManager.startSession(tier: duration.focusTier)
            return .result(value: "Started focus session for \(minutes) minutes")
        } catch {
            throw IntentError.focusManagerError("Failed to start session: \(error.localizedDescription)")
        }
    }
}

// MARK: - Stop Focus Session Intent
struct StopFocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Focus Session"
    static var description = IntentDescription("Stop the current focus session")
    
    func perform() async throws -> some IntentResult {
        do {
            let focusManager: FocusManager = try await DependencyContainer.shared.resolve()
            try await focusManager.stopSession()
            return .result(value: "Stopped focus session")
        } catch {
            throw IntentError.focusManagerError("Failed to stop session: \(error.localizedDescription)")
        }
    }
}

// MARK: - Get Focus Stats Intent
struct GetFocusStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Focus Stats"
    static var description = IntentDescription("Get your focus statistics")
    
    func perform() async throws -> some IntentResult {
        do {
            let settings: SettingsManager = try await DependencyContainer.shared.resolve()
            let focusManager: FocusManager = try await DependencyContainer.shared.resolve()
            
            let totalTime = await focusManager.totalFocusTime
            let hours = Int(totalTime / 3600)
            let minutes = Int((totalTime.truncatingRemainder(dividingBy: 3600)) / 60)
            
            let overrides = await settings.analytics.overrideAttempts
            
            return .result(value: "Total focus time: \(hours)h \(minutes)m\nOverride attempts: \(overrides)")
        } catch {
            throw IntentError.settingsManagerError("Failed to get stats: \(error.localizedDescription)")
        }
    }
}

// MARK: - Intent Error Enum
enum IntentError: Error, CustomStringConvertible {
    case focusManagerError(String)
    case settingsManagerError(String)
    
    var description: String {
        switch self {
        case .focusManagerError(let message): return message
        case .settingsManagerError(let message): return message
        }
    }
} 