import Foundation

@MainActor
class DependencyContainer {
    static let shared = DependencyContainer()
    
    private var dependencies: [String: Any] = [:]
    
    private init() {
        // Register dependencies in the correct order
        let settingsManager = SettingsManager()
        let blockingManager = BlockingManager()
        
        // First register the individual managers
        register(settingsManager)
        register(blockingManager)
        
        // Initialize FocusManager with its dependencies
        FocusManager.shared = FocusManager(
            settingsManager: settingsManager,
            blockingManager: blockingManager
        )
        
        // Then register the FocusManager
        register(FocusManager.shared)
    }
    
    func register<T>(_ instance: T) {
        let key = String(describing: T.self)
        dependencies[key] = instance
    }
    
    func resolve<T>() throws -> T {
        let key = String(describing: T.self)
        guard let dependency = dependencies[key] as? T else {
            throw DependencyError.unregisteredDependency
        }
        return dependency
    }
}

enum DependencyError: Error {
    case unregisteredDependency
} 