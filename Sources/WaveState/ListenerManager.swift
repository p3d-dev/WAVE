import Foundation
import SwiftUI

// MARK: - ListenerManager

/// Manager for handling state listeners and notifications.
@MainActor
public final class ListenerManager<Persistent: PersistentState, Transient: Equatable & Sendable> {
    private var listeners: [(UUID, any StateListener)] = []

    /// Adds a listener to be notified of state changes.
    /// - Parameter listener: The listener to add.
    public func addListener(_ listener: any StateListener) {

        listeners.append((UUID(), listener))
    }

    /// Notifies all listeners of a state change.
    /// - Parameter stateHolder: The state holder with the new state.
    public func notifyListeners(with stateHolder: StateHolder<Persistent, Transient>) {
        var zombies: Set<UUID> = []

        for (uuid, listener) in listeners {
            if listener.zombie {
                zombies.insert(uuid)
            }
            else {

                listener.updateState(stateHolder)
            }
        }
        if !zombies.isEmpty {
            listeners.removeAll { zombies.contains($0.0) }
        }
    }
}
