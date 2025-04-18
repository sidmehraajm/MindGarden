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
    @StateObject private var focusManager = FocusManager()
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(focusManager)
                .environmentObject(settingsManager)
        }
    }
}
