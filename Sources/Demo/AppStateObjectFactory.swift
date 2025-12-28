import WaveState
import WaveViews

/// Replace 'AppStateObjectFactory' with your app's factory name.
/// This factory creates StateObjects and sets up the forwarding relationship with the state manager.
/// Views use @Environment(\.objectFactory) to get properly initialized StateObjects.
final class AppStateObjectFactory: StateObjectFactory {
    let stateManager: AppUIStateManager

    init(stateManager: AppUIStateManager) {
        self.stateManager = stateManager
    }

    /// PITFALL: Missing listener registrations - Ensure all StateObject types have a case here.
    /// PITFALL: Missing StateForwarder definition - Each StateObject must have a corresponding @StateForwarder
    /// to generate the forwarder class. Without it, state won't sync to the UI.
    /// Each forwarder automatically syncs app state with the StateObject via listener registration.
    @MainActor
    func generateStateForwarder<T>(type: T.Type) -> (any StateListener)? {
        if T.self == ExampleStateObject.self {
            return ExampleForwarder(stateManager: stateManager)
        }
        return nil
    }

    /// PITFALL: This creates a StateObject and registers it as a listener with the state manager.
    /// The StateObject will automatically stay in sync with app state changes.
    /// Never create StateObjects manually - always use this factory method for proper listener setup.
    @MainActor
    func makeStateObject<T>() -> T? {
        if let forwarder = generateStateForwarder(type: T.self) {
            // Get the StateObject from the forwarder (created by the macro)
            let so = forwarder.getStateObject()
            return so as? T
        }
        return nil
    }
}
