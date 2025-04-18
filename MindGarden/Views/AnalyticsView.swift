import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject private var focusManager: FocusManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var selectedTimeframe: Timeframe = .week
    
    enum Timeframe {
        case day
        case week
        case month
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Time frame picker
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        Text("Today").tag(Timeframe.day)
                        Text("Week").tag(Timeframe.week)
                        Text("Month").tag(Timeframe.month)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Summary cards
                    summaryCardsView
                    
                    // Charts
                    if #available(iOS 16.0, *) {
                        focusBreakChartView
                    } else {
                        legacyStatsView
                    }
                    
                    // Block stats
                    blockingStatsView
                }
                .padding()
            }
            .navigationTitle("Analytics")
        }
    }
    
    private var summaryCardsView: some View {
        HStack(spacing: 15) {
            SummaryCard(
                value: totalFocusHours,
                label: "Focus Hours",
                icon: "clock.fill",
                color: .green
            )
            
            SummaryCard(
                value: settingsManager.analytics.breaksTaken,
                label: "Breaks Taken",
                color: .orange,
                icon: "cup.and.saucer.fill"
            )
        }
    }
    
    @available(iOS 16.0, *)
    private var focusBreakChartView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus vs. Break Time")
                .font(.headline)
            
            Chart {
                BarMark(
                    x: .value("Category", "Focus"),
                    y: .value("Hours", totalFocusHours)
                )
                .foregroundStyle(.green)
                
                BarMark(
                    x: .value("Category", "Break"),
                    y: .value("Hours", totalBreakHours)
                )
                .foregroundStyle(.orange)
            }
            .frame(height: 200)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground)))
    }
    
    private var legacyStatsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus vs. Break Time")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(totalFocusHours, specifier: "%.1f")")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("Focus Hours")
                        .font(.caption)
                }
                
                Divider()
                
                VStack {
                    Text("\(totalBreakHours, specifier: "%.1f")")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("Break Hours")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground)))
    }
    
    private var blockingStatsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Blocking Statistics")
                .font(.headline)
            
            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text("Apps Blocked")
                        .font(.subheadline)
                    Text("\(settingsManager.selectedApps.count)")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading) {
                    Text("Websites Blocked")
                        .font(.subheadline)
                    Text("\(settingsManager.selectedWebsites.count)")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
            }
            
            if settingsManager.analytics.overrideAttempts > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Emergency passes used: \(settingsManager.analytics.overrideAttempts)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 5)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground)))
    }
    
    // Data calculations
    private var totalFocusHours: Double {
        let timeInterval = settingsManager.analytics.totalFocusTime
        return timeInterval / 3600
    }
    
    private var totalBreakHours: Double {
        let breakCount = settingsManager.analytics.breaksTaken
        // Estimate average break time (15 min per break)
        return Double(breakCount) * 15 / 60
    }
}

struct SummaryCard: View {
    let value: Double
    let label: String
    let color: Color
    let icon: String
    
    init(value: Double, label: String, color: Color, icon: String) {
        self.value = value
        self.label = label
        self.color = color
        self.icon = icon
    }
    
    init(value: Int, label: String, color: Color, icon: String) {
        self.value = Double(value)
        self.label = label
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            if value == Double(Int(value)) {
                Text("\(Int(value))")
                    .font(.system(size: 28, weight: .bold))
            } else {
                Text("\(value, specifier: "%.1f")")
                    .font(.system(size: 28, weight: .bold))
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground)))
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(FocusManager.shared)
        .environmentObject(SettingsManager())
} 