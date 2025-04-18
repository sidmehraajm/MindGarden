import Foundation

@MainActor
class DependencyContainer {
    static let shared = DependencyContainer()
    
    private var dependencies: [String: Any] = [:]
    
    private init() {
        // Register core dependencies here instead of relying on external registration
        register(SettingsManager())
        register(BlockingManager())
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