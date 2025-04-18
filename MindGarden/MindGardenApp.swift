//
//  MindGardenApp.swift
//  MindGarden
//
//  Created by Siddarth Mehra on 18/04/25.
//

import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity
import NetworkExtension

@main
struct MindGardenApp: App {
    @StateObject private var focusManager = FocusManager.shared
    
    // Explicitly resolve other managers for use in environment
    @StateObject private var settingsManager: SettingsManager
    @StateObject private var blockingManager: BlockingManager
    
    // Used to show the permissions prompt
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showingPermissionsPrompt = true
    
    init() {
        // Initialize the dependency container - this will create and register all dependencies
        let _ = DependencyContainer.shared
        
        // Resolve the managers from the dependency container
        do {
            let resolvedSettingsManager: SettingsManager = try DependencyContainer.shared.resolve()
            let resolvedBlockingManager: BlockingManager = try DependencyContainer.shared.resolve()
            
            // Initialize the StateObjects with the resolved managers
            _settingsManager = StateObject(wrappedValue: resolvedSettingsManager)
            _blockingManager = StateObject(wrappedValue: resolvedBlockingManager)
        } catch {
            fatalError("Failed to resolve required dependencies: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(focusManager)
                    .environmentObject(settingsManager)
                    .environmentObject(blockingManager)
                
                // Show onboarding if user hasn't seen it yet
                if !hasSeenOnboarding {
                    OnboardingView(isPresented: $hasSeenOnboarding)
                        .environmentObject(blockingManager)
                        .zIndex(2)
                }
                // Overlay the permissions prompt if needed
                else if showingPermissionsPrompt && !blockingManager.isAuthorized {
                    PermissionsView(isPresented: $showingPermissionsPrompt)
                        .environmentObject(blockingManager)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Check if user already granted permissions
                if blockingManager.isAuthorized {
                    showingPermissionsPrompt = false
                }
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var blockingManager: BlockingManager
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "Welcome to Mind Garden",
            description: "Cultivate focus by removing digital distractions throughout your day.",
            imageName: "leaf.fill",
            imageColor: .green
        ),
        OnboardingPage(
            title: "Block Distractions",
            description: "Choose which apps and websites to block during focus time.",
            imageName: "shield.fill",
            imageColor: .blue
        ),
        OnboardingPage(
            title: "Take Breaks",
            description: "Schedule short breaks to temporarily unlock your apps and websites.",
            imageName: "cup.and.saucer.fill",
            imageColor: .orange
        ),
        OnboardingPage(
            title: "Track Progress",
            description: "Monitor your focus sessions and see your improvement over time.",
            imageName: "chart.bar.fill",
            imageColor: .purple
        )
    ]
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                    
                    // Final permissions page
                    PermissionsPageView(requestAction: {
                        Task {
                            do {
                                try await blockingManager.requestAuthorization()
                            } catch {
                                print("Failed to request authorization: \(error)")
                            }
                        }
                    })
                    .tag(pages.count)
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                Button(action: {
                    if currentPage < pages.count {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        isPresented = true
                    }
                }) {
                    Text(currentPage < pages.count ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let imageColor: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: page.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(page.imageColor)
                .padding(.bottom, 50)
            
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .padding(.bottom, 8)
            
            Text(page.description)
                .font(.system(size: 17))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct PermissionsPageView: View {
    let requestAction: () -> Void
    @State private var isRequesting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(.green)
                .padding(.bottom, 50)
            
            Text("Screen Time Access")
                .font(.system(size: 32, weight: .bold))
                .padding(.bottom, 8)
            
            Text("Mind Garden needs permission to block distracting apps and websites during focus sessions.")
                .font(.system(size: 17))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button(action: {
                isRequesting = true
                requestAction()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isRequesting = false
                }
            }) {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.trailing, 5)
                    }
                    
                    Text("Allow Screen Time Access")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal, 30)
            }
            .disabled(isRequesting)
            .padding(.top, 20)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct PermissionsView: View {
    @EnvironmentObject private var blockingManager: BlockingManager
    @Binding var isPresented: Bool
    @State private var isRequesting = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { }  // Prevent dismissal by tapping outside
            
            VStack(spacing: 25) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .padding(.bottom, 10)
                
                Text("Welcome to Mind Garden")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("To help you stay focused, Mind Garden needs permission to block distracting apps and websites during focus sessions.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)
                
                Button(action: {
                    isRequesting = true
                    Task {
                        do {
                            try await blockingManager.requestAuthorization()
                            isPresented = false
                        } catch {
                            print("Failed to request authorization: \(error)")
                        }
                        isRequesting = false
                    }
                }) {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 5)
                        }
                        
                        Text("Allow Screen Time Access")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 30)
                }
                .disabled(isRequesting)
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Skip for Now")
                        .foregroundColor(.white.opacity(0.6))
                        .padding()
                }
            }
            .padding(.vertical, 50)
        }
    }
}
