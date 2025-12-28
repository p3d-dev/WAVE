import Foundation
import SwiftUI

// MARK: - PersistenceCoordinator

/// Coordinator for managing persistence lifecycle and delegating to PersistenceManager.
@MainActor
public final class PersistenceCoordinator<Persistent: PersistentState> {
    private let persistenceManager: PersistenceManager<Persistent>

    /// Initializes the coordinator with a persistence key.
    /// - Parameter persistenceKey: The key for storing state.
    public init(persistenceKey: String) {
        self.persistenceManager = PersistenceManager(persistenceKey: persistenceKey)
    }

    /// Loads the initial state from persistence.
    /// - Returns: The loaded state, or nil if none exists.
    public func loadInitialState() -> Persistent? {
        persistenceManager.loadState()
    }

    /// Saves the state if needed, based on the event.
    /// - Parameters:
    ///   - state: The state to save.
    ///   - event: The event that triggered the save.
    public func saveStateIfNeeded(_ state: Persistent, for event: any AppEvent) async {
        await persistenceManager.saveStateIfNeeded(state, for: event)
    }
}
