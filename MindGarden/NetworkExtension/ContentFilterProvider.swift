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
            } catch {
                NSLog("Failed to resolve SettingsManager: \(error)")
            }
        }
    }
    
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        Task {
            do {
                settingsManager = try await DependencyContainer.shared.resolve()
                selectedWebsites = await settingsManager?.selectedWebsites ?? []
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
    
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        settingsManager = nil
        selectedWebsites = []
        completionHandler()
    }
    
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        // Check if the flow is a web flow
        if let url = flow.url {
            let host = url.host ?? ""
            if selectedWebsites.contains(host) {
                return .drop()
            }
        }
        
        return .allow()
    }
} 