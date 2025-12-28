import Foundation
import SwiftUI

// MARK: - EffectsCoordinator

/// Actor for managing side effects execution after state updates.
public actor EffectsCoordinator<Persistent: PersistentState, Transient: Equatable & Sendable> {
    private var effects: (@Sendable (any AppEvent, AppState<Persistent, Transient>) async -> Void)?

    /// Sets the effects function.
    /// - Parameter effects: The function to execute effects.
    public func setEffects(
        _ effects: (@Sendable (any AppEvent, AppState<Persistent, Transient>) async -> Void)?
    ) {
        self.effects = effects
    }

    /// Executes effects for the given event and state.
    /// - Parameters:
    ///   - event: The event that triggered the effects.
    ///   - state: The current state.
    public func executeEffects(for event: any AppEvent, state: AppState<Persistent, Transient>)
        async
    {
        if let effects = effects {
            await effects(event, state)
        }
    }
}
