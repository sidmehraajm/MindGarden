import Foundation

@MainActor
class DependencyContainer {
    static let shared = DependencyContainer()
    
    private var dependencies: [String: Any] = [:]
    
    private init() {
        // Register default dependencies
        register(SettingsManager())
        register(FocusManager())
    }
    
    func register<T>(_ dependency: T) {
        let key = String(describing: T.self)
        dependencies[key] = dependency
    }
    
    func resolve<T>(_ type: T.Type) throws -> T {
        let key = String(describing: type)
        guard let dependency = dependencies[key] as? T else {
            throw DependencyError.unregisteredDependency
        }
        return dependency
    }
}

enum DependencyError: Error {
    case unregisteredDependency
} 