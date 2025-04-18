import SwiftUI

struct CountdownOverlayView: View {
    @EnvironmentObject private var focusManager: FocusManager
    @EnvironmentObject private var blockingManager: BlockingManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var timeRemaining: String = "--:--"
    @State private var timer: Timer?
    @State private var isShowingEmergencyAlert = false
    @State private var isEmergencyPassGranted = false
    @State private var progressValue: Double = 1.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent dismissal
            
            VStack(spacing: 30) {
                if focusManager.isInGracePeriod {
                    // Break mode
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 20)
                            .opacity(0.3)
                            .foregroundColor(.gray)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(progressValue))
                            .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.blue)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: progressValue)
                        
                        VStack {
                            Text(timeRemaining)
                                .font(.system(size: 60, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            
                            Text("Break Time")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(width: 250, height: 250)
                    .padding(.bottom, 20)
                    
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
                            handleEmergencyPass()
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
        .padding()
        .alert("Request Emergency Pass?", isPresented: $isShowingEmergencyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                requestEmergencyPass()
            }
        } message: {
            Text("This will temporarily unlock your apps for 1 hour. Use this only for important tasks.")
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
            progressValue = 1.0
            return
        }
        
        let remaining = endTime.timeIntervalSince(Date())
        if remaining <= 0 {
            timeRemaining = "00:00"
            progressValue = 0.0
        } else {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            timeRemaining = String(format: "%02d:%02d", minutes, seconds)
            
            // Calculate progress based on remaining time
            if let startTime = focusManager.breakStartTime {
                let totalDuration = endTime.timeIntervalSince(startTime)
                progressValue = remaining / totalDuration
            }
        }
    }
    
    private func handleEmergencyPass() {
        isShowingEmergencyAlert = true
    }
    
    private func requestEmergencyPass() {
        Task {
            isEmergencyPassGranted = await focusManager.requestEmergencyPass()
            if !isEmergencyPassGranted {
                // If emergency pass is denied, refresh blocking rules to ensure they're still applied
                await focusManager.refreshBlockingRules()
            }
        }
    }
} 