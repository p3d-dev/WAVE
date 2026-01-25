import Foundation
import WaveState

/// Events related to event logging and replay for debugging.
public enum EventLoggingEvent: AppEvent {
    /// Trigger replay of recorded events.
    case replay
    /// Clear the event log.
    case clear

    /// Logging events should not be persisted.
    public var persist: Bool { false }
    /// Logging events are not UI events.
    public var isUIEvent: Bool { false }
}

/// Transient state storing recent event logging entries.
public struct EventLoggingState: Equatable, Sendable {
    // simplified test to avoid array element comparisons
    public static func == (lhs: EventLoggingState, rhs: EventLoggingState) -> Bool {
        lhs.events.count == rhs.events.count
    }
    /// Logged events (most-recent-last).
    public var events: [EventEntry]

    public init(events: [EventEntry] = []) {
        self.events = events
    }
}

/// Reducer responsible for appending events to the transient log.
public struct EventLoggingReducer {
    /// Maximum number of entries to keep.
    private let maxEntries: Int

    /// Initializes a reducer with an optional retention limit.
    /// - Parameter maxEntries: Number of entries to retain (defaults to 200).
    public init(maxEntries: Int = 200) {
        self.maxEntries = maxEntries
    }

    /// Reduces the logging state for a dispatched event.
    /// - Parameters:
    ///   - state: Current logging state.
    ///   - EnqueuedEvent: Event being processed.
    /// - Returns: Updated logging state with the new entry appended.
    public func reduce(state: EventLoggingState, enqueuedEvent: EnqueuedEvent) -> EventLoggingState {
        if enqueuedEvent.event is EventLoggingEvent {
            if case .clear = enqueuedEvent.event as! EventLoggingEvent {
                return EventLoggingState(events: [])
            }
            return state
        }
        var newState = state
        newState.events.append(EventEntry(enqueuedEvent: enqueuedEvent))
        let overflow = newState.events.count - maxEntries
        if overflow > 0 {
            newState.events.removeFirst(overflow)
        }
        return newState
    }
}

/// Adapter reducer that embeds `EventLoggingReducer` into an `AppState`-like structure.
public struct EventLoggingAppReducer<State>: EventReducer {
    private let keyPath: WritableKeyPath<State, EventLoggingState>
    private let reducer: EventLoggingReducer

    /// Creates an adapter for a specific state key path.
    /// - Parameters:
    ///   - keyPath: Writable key path to the `EventLoggingState` slice.
    ///   - reducer: Underlying logging reducer (defaults to standard configuration).
    public init(
        keyPath: WritableKeyPath<State, EventLoggingState>,
        reducer: EventLoggingReducer = EventLoggingReducer()
    ) {
        self.keyPath = keyPath
        self.reducer = reducer
    }

    public func reduce(state: State, enqueuedEvent: EnqueuedEvent) -> State {
        var newState = state
        let loggingState = reducer.reduce(
            state: newState[keyPath: keyPath],
            enqueuedEvent: enqueuedEvent)
        newState[keyPath: keyPath] = loggingState
        return newState
    }
}
