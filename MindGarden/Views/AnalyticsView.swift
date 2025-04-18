import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    SummaryCard()
                    
                    DailyStatsChart()
                    
                    FocusTimeCard()
                    
                    OverrideAttemptsCard()
                }
                .padding()
            }
            .navigationTitle("Analytics")
        }
    }
}

struct SummaryCard: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Focus Time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatTime(settingsManager.analytics.totalFocusTime))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Override Attempts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(settingsManager.analytics.overrideAttempts)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color(hex: "ecf0f1"))
        .cornerRadius(12)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

struct DailyStatsChart: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Focus Time")
                .font(.title2)
                .fontWeight(.bold)
            
            Chart {
                ForEach(Array(settingsManager.analytics.dailyStats.keys.sorted().suffix(7)), id: \.self) { date in
                    if let stats = settingsManager.analytics.dailyStats[date] {
                        BarMark(
                            x: .value("Date", date, unit: .day),
                            y: .value("Focus Time", stats.focusTime / 3600)
                        )
                        .foregroundStyle(Color(hex: "3498db"))
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(hex: "ecf0f1"))
        .cornerRadius(12)
    }
}

struct FocusTimeCard: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus Time Distribution")
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(Array(settingsManager.analytics.dailyStats.keys.sorted().suffix(7)), id: \.self) { date in
                if let stats = settingsManager.analytics.dailyStats[date] {
                    HStack {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(formatTime(stats.focusTime))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(hex: "ecf0f1"))
        .cornerRadius(12)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

struct OverrideAttemptsCard: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Override Attempts")
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(Array(settingsManager.analytics.dailyStats.keys.sorted().suffix(7)), id: \.self) { date in
                if let stats = settingsManager.analytics.dailyStats[date] {
                    HStack {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(stats.overrideAttempts)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(hex: "ecf0f1"))
        .cornerRadius(12)
    }
} 