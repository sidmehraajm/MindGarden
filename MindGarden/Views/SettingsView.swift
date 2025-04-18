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
                        }
                    }
                }
                
                Section(header: Text("Break Durations")) {
                    NavigationLink("Configure Break Times") {
                        BreakDurationView()
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
                NavigationView {
                    FamilyActivityPicker(selection: $selectedActivitySelection)
                        .navigationTitle("Select Apps")
                        .navigationBarItems(
                            trailing: Button("Done") {
                                showingAppPicker = false
                                // Just store a placeholder identifier for demo purposes
                                // In a real app, you would want to properly extract identifiers
                                if !selectedActivitySelection.applicationTokens.isEmpty {
                                    settingsManager.selectedApps = ["com.example.app1", "com.example.app2"]
                                }
                            }
                        )
                }
            }
        }
    }
}

struct BreakDurationView: View {
    @AppStorage("shortBreakMinutes") private var shortBreakMinutes = 5
    @AppStorage("mediumBreakMinutes") private var mediumBreakMinutes = 15
    @AppStorage("longBreakMinutes") private var longBreakMinutes = 30
    
    var body: some View {
        Form {
            Section(header: Text("Break Durations")) {
                Stepper("Short Break: \(shortBreakMinutes) min", value: $shortBreakMinutes, in: 1...15)
                Stepper("Medium Break: \(mediumBreakMinutes) min", value: $mediumBreakMinutes, in: 10...30)
                Stepper("Long Break: \(longBreakMinutes) min", value: $longBreakMinutes, in: 15...60)
            }
            
            Section(header: Text("About Breaks")) {
                Text("Breaks temporarily pause blocking of apps and websites. After the break ends, blocking will resume automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Break Durations")
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
                    Text("Choose which apps you want to block during the day. These apps will be inaccessible unless you take a break.")
                    
                    Text("2. Add Websites to Block")
                        .font(.headline)
                    Text("Enter the URLs of websites you want to block throughout the day. These sites will be inaccessible unless you take a break.")
                    
                    Text("3. All-Day Focus")
                        .font(.headline)
                    Text("Mind Garden blocks your selected apps and websites all day to help you maintain focus.")
                    
                    Text("4. Break Types")
                        .font(.headline)
                    Text("When you need access to blocked content, you can choose a break:\n• Short Break (5 minutes)\n• Medium Break (15 minutes)\n• Long Break (30 minutes)\nAfter your break ends, blocking will automatically resume.")
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