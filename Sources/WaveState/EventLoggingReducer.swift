import Foundation

/// Transient state storing recent event logging entries.
public struct EventLoggingState: Equatable, Sendable {
    /// Logged events (most-recent-last).
    public var events: [EventLoggingEntry]

    public init(events: [EventLoggingEntry] = []) {
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
    ///   - event: Event being processed.
    /// - Returns: Updated logging state with the new entry appended.
    public func reduce(state: EventLoggingState, queuedEvent: QueuedEvent) -> EventLoggingState {
        var newState = state
        newState.events.append(EventLoggingEntry(queuedEvent: queuedEvent))
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

    public func reduce(state: State, queuedEvent: QueuedEvent) -> State {
        var newState = state
        let loggingState = reducer.reduce(
            state: newState[keyPath: keyPath],
            queuedEvent: queuedEvent)
        newState[keyPath: keyPath] = loggingState
        return newState
    }
}
