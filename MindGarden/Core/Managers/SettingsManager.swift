import Foundation
import Combine
import FamilyControls

@MainActor
class SettingsManager: ObservableObject {
    @Published var selectedApps: Set<String> = []
    @Published var selectedWebsites: Set<String> = []
    @Published var analytics = Analytics()
    
    private let userDefaults = UserDefaults.standard
    private let appsKey = "selectedApps"
    private let websitesKey = "selectedWebsites"
    private let analyticsKey = "analytics"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load saved data
        if let appsData = userDefaults.data(forKey: appsKey),
           let apps = try? JSONDecoder().decode(Set<String>.self, from: appsData) {
            selectedApps = apps
        }
        
        if let websitesData = userDefaults.data(forKey: websitesKey),
           let websites = try? JSONDecoder().decode(Set<String>.self, from: websitesData) {
            selectedWebsites = websites
        }
        
        if let analyticsData = userDefaults.data(forKey: analyticsKey),
           let analytics = try? JSONDecoder().decode(Analytics.self, from: analyticsData) {
            self.analytics = analytics
        }
        
        // Save changes
        $selectedApps
            .dropFirst()
            .sink { [weak self] apps in
                self?.saveSelectedApps()
            }
            .store(in: &cancellables)
        
        $selectedWebsites
            .dropFirst()
            .sink { [weak self] websites in
                self?.saveSelectedWebsites()
            }
            .store(in: &cancellables)
        
        $analytics
            .dropFirst()
            .sink { [weak self] analytics in
                if let data = try? JSONEncoder().encode(analytics) {
                    self?.userDefaults.set(data, forKey: self?.analyticsKey ?? "")
                }
            }
            .store(in: &cancellables)
    }
    
    func updateSelectedApps(_ apps: Set<String>) {
        selectedApps = apps
    }
    
    func updateSelectedWebsites(_ websites: Set<String>) {
        selectedWebsites = websites
    }
    
    func updateAnalytics(_ analytics: Analytics) {
        self.analytics = analytics
    }
    
    func saveSelectedApps() {
        if let data = try? JSONEncoder().encode(selectedApps) {
            userDefaults.set(data, forKey: appsKey)
        }
    }
    
    func saveSelectedWebsites() {
        if let data = try? JSONEncoder().encode(selectedWebsites) {
            userDefaults.set(data, forKey: websitesKey)
        }
    }
}

struct Analytics: Codable {
    var totalFocusTime: TimeInterval = 0
    var overrideAttempts: Int = 0
    var dailyStats: [Date: DailyStats] = [:]
}

struct DailyStats: Codable {
    var focusTime: TimeInterval
    var overrideAttempts: Int
    var completedSessions: Int
    
    init(focusTime: TimeInterval = 0, overrideAttempts: Int = 0, completedSessions: Int = 0) {
        self.focusTime = focusTime
        self.overrideAttempts = overrideAttempts
        self.completedSessions = completedSessions
    }
} 