import WaveDemo
import WaveState
import WaveViews
import WaveEventLogger
import SwiftUI

/// Replace 'AppStateObjectFactory' with your app's factory name.
/// This factory creates StateObjects and sets up the forwarding relationship with the state manager.
/// Views use @Environment(\.objectFactory) to get properly initialized StateObjects.
final class AppStateObjectFactory: StateObjectFactory {
    let stateManager: AppUIStateManager

    init(stateManager: AppUIStateManager) {
        self.stateManager = stateManager
    }

    /// PITFALL: This creates a StateObject and registers it as a listener with the state manager.
    /// The StateObject will automatically stay in sync with app state changes.
    /// Never create StateObjects manually - always use this factory method for proper listener setup.
    @MainActor
    func makeStateObject<T>() -> StateObject<T>? {
        if T.self == ExampleStateObject.self {
            return ExampleForwarder(stateManager: stateManager).getStateObject() as? StateObject<T>
        }
        if T.self == EventStateObject.self {
            return EventForwarder(stateManager: stateManager).getStateObject() as? StateObject<T>
        }
        return nil
    }
}
