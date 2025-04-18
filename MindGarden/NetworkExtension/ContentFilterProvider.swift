import Foundation
import NetworkExtension
import ManagedSettings

class ContentFilterProvider: NEFilterDataProvider {
    private var settingsManager: SettingsManager?
    private var selectedWebsites: Set<String> = []
    
    override init() {
        super.init()
        Task {
            do {
                settingsManager = try await DependencyContainer.shared.resolve()
                selectedWebsites = await settingsManager?.selectedWebsites ?? []
                NSLog("ContentFilterProvider initialized with \(selectedWebsites.count) websites")
            } catch {
                NSLog("Failed to resolve SettingsManager: \(error)")
            }
        }
    }
    
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        NSLog("Starting ContentFilterProvider")
        Task {
            do {
                settingsManager = try await DependencyContainer.shared.resolve()
                selectedWebsites = await settingsManager?.selectedWebsites ?? []
                NSLog("ContentFilterProvider started with \(selectedWebsites.count) websites")
                completionHandler(nil)
            } catch {
                NSLog("Failed to start filter: \(error)")
                completionHandler(error)
            }
        }
    }
    
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("Stopping ContentFilterProvider with reason: \(reason.rawValue)")
        settingsManager = nil
        selectedWebsites = []
        completionHandler()
    }
    
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let flow = flow as? NEFilterBrowserFlow,
              let url = flow.url,
              let host = url.host,
              !host.isEmpty else {
            return .allow()
        }
        
        if selectedWebsites.contains(host) {
            NSLog("Blocking access to \(host)")
            return .drop()
        }
        
        // Allow all other URLs
        return .allow()
    }
} 