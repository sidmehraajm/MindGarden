import SwiftUI
import FamilyControls

struct ContentView: View {
    @StateObject private var focusManager: FocusManager
    @StateObject private var settingsManager: SettingsManager
    
    init() {
        // Get shared instances from DependencyContainer
        let container = DependencyContainer.shared
        do {
            let focus: FocusManager = try container.resolve()
            let settings: SettingsManager = try container.resolve()
            self._focusManager = StateObject(wrappedValue: focus)
            self._settingsManager = StateObject(wrappedValue: settings)
        } catch {
            // Fallback to shared instance if dependency resolution fails
            self._focusManager = StateObject(wrappedValue: FocusManager.shared)
            self._settingsManager = StateObject(wrappedValue: SettingsManager())
            print("Error resolving dependencies: \(error)")
        }
    }
    
    var body: some View {
        TabView {
            FocusView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            
            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }
        }
        .environmentObject(focusManager)
        .environmentObject(settingsManager)
    }
}

#Preview {
    ContentView()
}

struct FocusView: View {
    @EnvironmentObject private var focusManager: FocusManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if focusManager.isActive {
                    ActiveSessionView()
                } else {
                    FocusTierSelectionView()
                }
            }
            .navigationTitle("Mind Garden")
            .padding()
        }
    }
}

struct FocusTierSelectionView: View {
    @EnvironmentObject private var focusManager: FocusManager
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(FocusManager.FocusTier.allCases, id: \.self) { tier in
                Button(action: { 
                    Task {
                        await focusManager.startSession(tier: tier)
                    }
                }) {
                    VStack {
                        Text(tierTitle(for: tier))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(tier.rawValue) minutes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "ecf0f1"))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func tierTitle(for tier: FocusManager.FocusTier) -> String {
        switch tier {
        case .low: return "Low Focus"
        case .medium: return "Medium Focus"
        case .high: return "High Focus"
        case .deep: return "Deep Focus"
        }
    }
}

struct ActiveSessionView: View {
    @EnvironmentObject private var focusManager: FocusManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text(timeString(from: focusManager.remainingTime))
                .font(.system(size: 60, weight: .bold, design: .monospaced))
            
            if let session = focusManager.currentSession {
                Text(session.isDeepFocus ? "Deep Focus Mode" : "Focus Mode Active")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                Task {
                    do {
                        try await focusManager.stopSession()
                    } catch {
                        print("Failed to stop session: \(error)")
                    }
                }
            }) {
                Text("End Session")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "2ecc71"))
                    .cornerRadius(12)
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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