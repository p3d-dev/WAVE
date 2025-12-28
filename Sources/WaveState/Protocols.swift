import Foundation
import SwiftUI

// MARK: - State Events

/// Event dispatched when state is restored from persistence.
/// Used internally by UIStateManager to initialize state from disk.
public struct StateRestoreEvent<Persistent: Codable & Equatable & Sendable>: AppEvent {
    /// The state that was restored from persistence.
    public let restoredState: Persistent

    /// Initializes the restore event with the loaded state.
    public init(restoredState: Persistent) {
        self.restoredState = restoredState
    }

    /// Restoration events should not trigger re-persistence.
    public var persist: Bool { false }
    /// Restoration is not a UI event.
    public var isUIEvent: Bool { false }
}

/// Event to reset state to default values.
/// Dispatched when the user wants to clear all settings.
public struct ResetEvent: AppEvent {
    /// Initializes the reset event.
    public init() {}
    /// Reset should be persisted to save the default state.
    public var persist: Bool { true }
    /// Reset is a UI event (user-initiated).
    public var isUIEvent: Bool { true }
}

/// Events related to event recording and replay for debugging.
public enum EventRecorderEvent: AppEvent {
    /// Trigger replay of recorded events.
    case replay

    /// Recording events should not be persisted.
    public var persist: Bool { false }
    /// Recording events are not UI events.
    public var isUIEvent: Bool { false }
}

// MARK: - Reducer Protocols

/// Protocol for pure functions that reduce state based on queued events.
/// Reducers must be pure: they take the current state and the full queued event (event + metadata),
/// returning a new state. They should not have side effects.
public protocol EventReducer {
    /// The type of state this reducer operates on.
    associatedtype State

    /// Reduces the state based on the given queued event.
    /// - Parameters:
    ///   - state: The current state.
    ///   - queuedEvent: The queued event (with timestamp metadata) to process.
    /// - Returns: The new state after applying the event.
    func reduce(state: State, queuedEvent: QueuedEvent) -> State
}

/// Type-erased wrapper for EventReducer to enable heterogeneous collections.
/// Allows storing different reducer types in the same collection.
public struct AnyReducer<S>: EventReducer {
    /// The underlying reduce function.
    private let _reduce: (S, QueuedEvent) -> S

    /// Initializes with a concrete reducer implementation.
    public init<R: EventReducer>(_ reducer: R) where R.State == S {
        _reduce = reducer.reduce
    }

    /// Reduces the state using the wrapped reducer.
    public func reduce(state: S, queuedEvent: QueuedEvent) -> S {
        _reduce(state, queuedEvent)
    }
}

/// Event queued with timestamp metadata for processing.
/// Used by the state manager to track event timing and ordering.
public struct QueuedEvent: Sendable {
    /// The event being queued.
    public let event: any AppEvent
    /// Timestamp when the event was queued (nanoseconds since boot).
    public let timestamp: UInt64

    /// Initializes a queued event with the given event and current timestamp.
    public init(event: any AppEvent) {
        self.event = event
        self.timestamp = DispatchTime.now().uptimeNanoseconds
    }
}

// MARK: - Persistence

/// Protocol for persistence managers that handle saving and loading state.
/// Implementations should handle serialization, debouncing, and error recovery.
protocol PersistenceManagerProtocol: AnyObject, Sendable {
    /// The type of state this manager persists.
    associatedtype State: Codable & Equatable & Sendable

    /// Saves the state if the event requires persistence, with debouncing.
    func saveStateIfNeeded(_ state: State, for event: any AppEvent) async
    /// Loads the previously saved state, or nil if none exists.
    func loadState() -> State?
    /// Immediately saves the state without debouncing.
    @MainActor func saveStateImmediately(_ state: State)
}

/// Empty transient state for cases where no transient state is needed.
/// Useful for simple apps that only have persistent state.
public struct EmptyTransient: Equatable, Sendable {
    /// Initializes empty transient state.
    public init() {}
}

// MARK: - State Listeners

/// Protocol for objects that listen to state changes.
/// Listeners are notified whenever the state is updated and can react accordingly.
/// This enables reactive UI updates and side effects.
///
/// Design Decision: @MainActor to ensure UI updates happen on the main thread.
/// Conforms to Sendable for safe concurrent access.
@MainActor
public protocol StateListener: AnyObject, Sendable {
    /// The type of object this listener manages.
    associatedtype T

    /// Indicates if this listener has been deallocated (zombie state).
    /// Used by UIStateManager to clean up weak references.
    var zombie: Bool { get }

    /// Called when the state has been updated.
    /// - Parameter stateHolder: The state holder containing the new state.
    func updateState(_ stateHolder: AnyObject)

    /// Returns the object managed by this listener.
    func getStateObject() -> T
}
