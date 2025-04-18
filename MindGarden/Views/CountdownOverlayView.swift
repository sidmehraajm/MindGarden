import SwiftUI

struct CountdownOverlayView: View {
    @EnvironmentObject private var focusManager: FocusManager
    @EnvironmentObject private var blockingManager: BlockingManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var timeRemaining: String = "--:--"
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent dismissal
            
            VStack(spacing: 30) {
                if focusManager.isInGracePeriod {
                    // Break mode
                    Text(timeRemaining)
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .transition(.opacity)
                    
                    Text("Break Time")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button(action: {
                        Task {
                            await focusManager.endBreakEarly()
                        }
                    }) {
                        Text("End Break")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                } else {
                    // Focus mode
                    Text("Focus Mode")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                    
                    Text("Blocking distractions")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                    
                    VStack(spacing: 15) {
                        Button(action: {
                            Task {
                                await focusManager.startBreak(duration: 300) // 5 minutes
                            }
                        }) {
                            Text("5 Minute Break")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: 250)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            Task {
                                await focusManager.startBreak(duration: 900) // 15 minutes
                            }
                        }) {
                            Text("15 Minute Break")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: 250)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            Task {
                                await focusManager.requestEmergencyPass()
                            }
                        }) {
                            Text("Emergency Pass (1hr)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: 250)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Reapply restrictions when app becomes active
                if !focusManager.isInGracePeriod {
                    Task {
                        await blockingManager.refreshBlockingRules()
                    }
                }
                startTimer()
            }
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        updateTimeRemaining()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        guard let endTime = focusManager.breakEndTime else {
            timeRemaining = "--:--"
            return
        }
        
        let remaining = endTime.timeIntervalSince(Date())
        if remaining <= 0 {
            timeRemaining = "00:00"
        } else {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            timeRemaining = String(format: "%02d:%02d", minutes, seconds)
        }
    }
} 