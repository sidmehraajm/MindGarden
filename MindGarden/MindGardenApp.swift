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
    // Use StateObjects for the shared instances
    @StateObject private var focusManager = FocusManager.shared
    
    init() {
        // Initialize the dependency container first
        let _ = DependencyContainer.shared
        // Set up dependencies
        FocusManager.shared.setupDependencies()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Request authorization when app starts
                    do {
                        try await focusManager.requestAuthorization()
                    } catch {
                        print("Failed to request authorization: \(error)")
                    }
                }
        }
    }
}
