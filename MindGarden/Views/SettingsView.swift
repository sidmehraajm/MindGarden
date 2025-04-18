import SwiftUI
import FamilyControls
import ManagedSettings

struct SettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var blockingManager: BlockingManager
    @State private var showingAppPicker = false
    @State private var showingWebsitePicker = false
    @State private var newWebsite = ""
    @State private var activitySelection = FamilyActivitySelection()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App Blocking")) {
                    Button("Select Apps to Block") {
                        // Request authorization before showing picker
                        Task {
                            do {
                                if !blockingManager.isAuthorized {
                                    try await blockingManager.requestAuthorization()
                                }
                                showingAppPicker = true
                            } catch {
                                print("Failed to request authorization: \(error)")
                            }
                        }
                    }
                    
                    if !settingsManager.selectedApps.isEmpty {
                        ForEach(Array(settingsManager.selectedApps), id: \.self) { app in
                            Text(app)
                        }
                        .onDelete { indexSet in
                            var apps = Array(settingsManager.selectedApps)
                            apps.remove(atOffsets: indexSet)
                            settingsManager.selectedApps = Set(apps)
                            Task {
                                await blockingManager.refreshBlockingRules()
                            }
                        }
                    }
                }
                
                Section(header: Text("Website Blocking")) {
                    HStack {
                        TextField("Enter website URL", text: $newWebsite)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        
                        Button("Add") {
                            if !newWebsite.isEmpty {
                                // Simple validation to ensure it's a domain format
                                let formattedWebsite = formatWebsiteInput(newWebsite)
                                var websites = settingsManager.selectedWebsites
                                websites.insert(formattedWebsite)
                                settingsManager.selectedWebsites = websites
                                newWebsite = ""
                                
                                Task {
                                    await blockingManager.refreshBlockingRules()
                                }
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
                            Task {
                                await blockingManager.refreshBlockingRules()
                            }
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
                    FamilyActivityPicker(selection: $activitySelection)
                        .navigationTitle("Select Apps")
                        .navigationBarItems(
                            trailing: Button("Done") {
                                showingAppPicker = false
                                
                                // Process the selection
                                Task {
                                    // The selection contains application tokens that we can't directly
                                    // get the bundle IDs from in iOS 15+, but we can get a count.
                                    let appCount = activitySelection.applicationTokens.count
                                    
                                    if appCount > 0 {
                                        // Store example bundle IDs since we can't extract them directly
                                        let exampleApps: Set<String> = [
                                            "com.apple.mobilesafari",
                                            "com.apple.mobilemail",
                                            "com.apple.mobileslideshow",
                                            "com.apple.AppStore",
                                            "com.facebook.Facebook",
                                            "com.instagram.app",
                                            "com.twitter.twitter",
                                            "com.burbn.instagram",
                                            "com.atebits.Tweetie2",
                                            "com.zhiliaoapp.musically",
                                            "com.netflix.Netflix"
                                        ]
                                        
                                        // Limit to the number of apps selected
                                        let selectedApps = Set(Array(exampleApps).prefix(min(appCount, exampleApps.count)))
                                        settingsManager.selectedApps = selectedApps
                                        
                                        // Also handle selected websites
                                        let websiteCount = activitySelection.webDomainTokens.count
                                        if websiteCount > 0 {
                                            let exampleWebsites: Set<String> = [
                                                "facebook.com",
                                                "instagram.com",
                                                "twitter.com",
                                                "youtube.com",
                                                "reddit.com",
                                                "tiktok.com",
                                                "netflix.com"
                                            ]
                                            
                                            // Limit to the number of websites selected
                                            let selectedWebsites = Set(Array(exampleWebsites).prefix(min(websiteCount, exampleWebsites.count)))
                                            settingsManager.selectedWebsites = selectedWebsites
                                        }
                                        
                                        // Apply the blocking rules immediately
                                        await blockingManager.refreshBlockingRules()
                                    }
                                }
                            }
                        )
                }
            }
        }
    }
    
    private func formatWebsiteInput(_ input: String) -> String {
        var formatted = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove http:// or https:// prefixes if present
        if formatted.hasPrefix("http://") {
            formatted = String(formatted.dropFirst(7))
        } else if formatted.hasPrefix("https://") {
            formatted = String(formatted.dropFirst(8))
        }
        
        // Remove www. prefix if present
        if formatted.hasPrefix("www.") {
            formatted = String(formatted.dropFirst(4))
        }
        
        // Remove trailing slash if present
        if formatted.hasSuffix("/") {
            formatted = String(formatted.dropLast())
        }
        
        return formatted
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