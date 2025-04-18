import SwiftUI

struct CountdownOverlayView: View {
    @EnvironmentObject private var focusManager: FocusManager
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent dismissal
            
            VStack(spacing: 30) {
                Text(timeString(from: focusManager.remainingTime))
                    .font(.system(size: 80, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .transition(.opacity)
                
                if let session = focusManager.currentSession {
                    Text(session.isDeepFocus ? "Deep Focus Mode" : "Focus Mode Active")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if session.isDeepFocus {
                        Button(action: {
                            if focusManager.requestEmergencyPass() {
                                // Emergency pass granted
                            }
                        }) {
                            Text("Emergency Pass")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Reapply restrictions when app becomes active
                focusManager.reapplyDeepFocusRestrictions()
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 