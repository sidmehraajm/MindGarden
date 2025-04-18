import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject private var focusManager: FocusManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var blockingManager: BlockingManager
    
    var body: some View {
        TabView {
            FocusView()
                .tabItem {
                    Label("Focus", systemImage: "brain.head.profile")
                }
            
            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}

struct FocusView: View {
    @EnvironmentObject private var focusManager: FocusManager
    @AppStorage("shortBreakMinutes") private var shortBreakMinutes = 5
    @AppStorage("mediumBreakMinutes") private var mediumBreakMinutes = 15
    @AppStorage("longBreakMinutes") private var longBreakMinutes = 30
    @State private var showingBreakOptions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Focus status card
                VStack(spacing: 15) {
                    if focusManager.isInGracePeriod {
                        BreakTimerView()
                    } else {
                        FocusStatusView()
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground)))
                
                // Action buttons
                if focusManager.isInGracePeriod {
                    Button(action: {
                        Task {
                            await focusManager.endBreakEarly()
                        }
                    }) {
                        Text("End Break Early")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    Button(action: {
                        showingBreakOptions = true
                    }) {
                        Text("Take a Break")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .actionSheet(isPresented: $showingBreakOptions) {
                        ActionSheet(
                            title: Text("Select Break Duration"),
                            message: Text("Apps and websites will be unblocked temporarily"),
                            buttons: [
                                .default(Text("Short Break (\(shortBreakMinutes) min)")) {
                                    Task {
                                        await focusManager.startBreak(duration: TimeInterval(shortBreakMinutes * 60))
                                    }
                                },
                                .default(Text("Medium Break (\(mediumBreakMinutes) min)")) {
                                    Task {
                                        await focusManager.startBreak(duration: TimeInterval(mediumBreakMinutes * 60))
                                    }
                                },
                                .default(Text("Long Break (\(longBreakMinutes) min)")) {
                                    Task {
                                        await focusManager.startBreak(duration: TimeInterval(longBreakMinutes * 60))
                                    }
                                },
                                .cancel()
                            ]
                        )
                    }
                }
                
                // Stats preview
                StatsPreviewView()
                
                Spacer()
            }
            .navigationTitle("Mind Garden")
            .padding()
        }
    }
}

struct FocusStatusView: View {
    @EnvironmentObject private var focusManager: FocusManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
                .padding(.bottom, 5)
            
            Text("Focus Mode Active")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Blocking \(settingsManager.selectedApps.count) apps and \(settingsManager.selectedWebsites.count) websites")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("All-day focus is enabled")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
        .padding()
    }
}

struct BreakTimerView: View {
    @EnvironmentObject private var focusManager: FocusManager
    @State private var timeRemaining: String = "--:--"
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .padding(.bottom, 5)
            
            Text("Break Time")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(timeRemaining)
                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                .foregroundColor(.orange)
                .padding(.vertical, 5)
            
            Text("Apps and websites are unblocked")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .onAppear {
            updateTimer()
            // Start a timer to update the remaining time
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateTimer()
            }
        }
    }
    
    private func updateTimer() {
        guard let endTime = focusManager.breakEndTime else {
            timeRemaining = "--:--"
            return
        }
        
        let remaining = endTime.timeIntervalSince(Date())
        if remaining <= 0 {
            timeRemaining = "00:00"
            return
        }
        
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        timeRemaining = String(format: "%02d:%02d", minutes, seconds)
    }
}

struct StatsPreviewView: View {
    @EnvironmentObject private var focusManager: FocusManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Today's Stats")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatBox(
                    value: focusManager.totalFocusMinutesToday,
                    label: "Focus Minutes",
                    icon: "clock.fill",
                    color: .green
                )
                
                StatBox(
                    value: settingsManager.analytics.breaksTaken,
                    label: "Breaks Taken",
                    icon: "cup.and.saucer.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground)))
    }
}

struct StatBox: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 18))
            
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 