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
            ContentView()
                .environmentObject(focusManager)
                .environmentObject(settingsManager)
                .environmentObject(blockingManager)
        }
    }
}
