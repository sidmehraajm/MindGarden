import SwiftUI
import FamilyControls
import ManagedSettings

struct SettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var showingAppPicker = false
    @State private var showingWebsitePicker = false
    @State private var newWebsite = ""
    @State private var selectedActivitySelection = FamilyActivitySelection()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App Blocking")) {
                    Button("Select Apps to Block") {
                        showingAppPicker = true
                    }
                    
                    if !settingsManager.selectedApps.isEmpty {
                        ForEach(Array(settingsManager.selectedApps), id: \.self) { app in
                            Text(app)
                        }
                        .onDelete { indexSet in
                            var apps = Array(settingsManager.selectedApps)
                            apps.remove(atOffsets: indexSet)
                            settingsManager.selectedApps = Set(apps)
                            settingsManager.saveSelectedApps()
                        }
                    }
                }
                
                Section(header: Text("Website Blocking")) {
                    HStack {
                        TextField("Enter website URL", text: $newWebsite)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                        
                        Button("Add") {
                            if !newWebsite.isEmpty {
                                var websites = settingsManager.selectedWebsites
                                websites.insert(newWebsite)
                                settingsManager.selectedWebsites = websites
                                settingsManager.saveSelectedWebsites()
                                newWebsite = ""
                            }
                        }
                    }
                    
                    if !settingsManager.selectedWebsites.isEmpty {
                        ForEach(Array(settingsManager.selectedWebsites), id: \.self) { website in
                            Text(website)
                        }
                        .onDelete { indexSet in
                            var websites = Array(settingsManager.selectedWebsites)
                            websites.remove(atOffsets: indexSet)
                            settingsManager.selectedWebsites = Set(websites)
                            settingsManager.saveSelectedWebsites()
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    NavigationLink("How to Use") {
                        TutorialView()
                    }
                    
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAppPicker) {
                FamilyActivityPicker(selection: $selectedActivitySelection)
                    .onDisappear {
                        // Just store a placeholder identifier for demo purposes
                        // In a real app, you would want to properly extract identifiers
                        if !selectedActivitySelection.applicationTokens.isEmpty {
                            settingsManager.selectedApps = ["com.example.app1", "com.example.app2"]
                            settingsManager.saveSelectedApps()
                        }
                    }
            }
        }
    }
}

struct TutorialView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Getting Started")
                        .font(.title)
                        .padding(.bottom)
                    
                    Text("1. Select Apps to Block")
                        .font(.headline)
                    Text("Choose which apps you want to block during focus sessions. These apps will be inaccessible during active focus periods.")
                    
                    Text("2. Add Websites to Block")
                        .font(.headline)
                    Text("Enter the URLs of websites you want to block. These sites will be inaccessible during focus sessions.")
                    
                    Text("3. Choose Focus Tier")
                        .font(.headline)
                    Text("Select from four focus tiers:\n• Low (5 minutes)\n• Medium (15 minutes)\n• High (30 minutes)\n• Deep (60 minutes)")
                    
                    Text("4. Start Focus Session")
                        .font(.headline)
                    Text("Tap on your desired focus tier to begin. The timer will show your remaining time, and selected apps/websites will be blocked.")
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Tutorial")
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Privacy Policy")
                        .font(.title)
                        .padding(.bottom)
                    
                    Text("Data Collection")
                        .font(.headline)
                    Text("Mind Garden processes all data locally on your device. We do not collect, store, or transmit any personal information to external servers.")
                    
                    Text("Permissions")
                        .font(.headline)
                    Text("The app requires Screen Time permissions to block apps and websites. These permissions are used solely for the app's core functionality and are not shared with any third parties.")
                    
                    Text("Analytics")
                        .font(.headline)
                    Text("Usage statistics are stored locally on your device and can be cleared at any time. No analytics data is shared externally.")
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
} 