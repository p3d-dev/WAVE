import Atomics
import Combine
import Foundation
import SwiftUI

// MARK: - UIStateManager Actor

final class StateBox<Persistent, Transient>: AtomicReference, Sendable
where Persistent: PersistentState, Transient: Equatable & Sendable {
    let state: AppState<Persistent, Transient>

    /// Initializes the state holder with an initial state.
    /// - Parameter state: The initial state value.
    init(state: AppState<Persistent, Transient>) {
        self.state = state
    }
}

/// Actor-based UI state manager that handles event dispatching, state updates, and listener notifications.
/// Manages the unidirectional data flow in a thread-safe manner using Swift concurrency.
public actor UIStateManager<Persistent, Transient>
where Persistent: PersistentState, Transient: Equatable & Sendable {
    /// The observable state holder that notifies SwiftUI views of state changes
    nonisolated let stateBox: ManagedAtomic<StateBox<Persistent, Transient>>
    /// Unique identifier for this state manager instance
    public nonisolated let uuid = UUID()
    /// Factory function to create the default state
    private let defaultState: () -> AppState<Persistent, Transient>
    /// Pure function that transforms state based on events
    private var reducers: [AnyReducer<AppState<Persistent, Transient>>] = []
    /// Coordinator for persistence
    private let persistenceCoordinator: PersistenceCoordinator<Persistent>?
    /// Coordinator for effects
    private let effectsCoordinator: EffectsCoordinator<Persistent, Transient>
    /// Manager for listeners
    private let listenerManager: ListenerManager<Persistent, Transient>
    /// Optional filter to control which events are processed
    public var dispatchFilter: ((any AppEvent) async -> Bool)?
    /// Continuation for the event processing stream
    private var continuation: AsyncStream<EnqueuedEvent>.Continuation?

    /// Number of events dispatched (for testing/debugging)
    public private(set) var eventsDispatched: Int = 0
    /// Number of events processed (for testing/debugging)
    public private(set) var eventsProcessed: Int = 0

    /// The current state value (convenience accessor)

    public var state: AppState<Persistent, Transient> {
        stateBox.load(ordering: .relaxed).state
    }

    nonisolated public func getState() -> AppState<Persistent, Transient> {
        stateBox.load(ordering: .relaxed).state
    }

    /// Waits for all dispatched events to be processed (debug/testing only)
    /// - Note: This is a blocking wait with a 1-second timeout
    public func debugWaitForEventsProcessed() async {
        let start = Date()
        while eventsDispatched != eventsProcessed, Date().timeIntervalSince(start) < 1.0 {
            try? await Task.sleep(nanoseconds: 5_000_000)  // 5ms
        }
    }

    /// Initializes the UI state manager with required dependencies
    /// - Parameters:
    ///   - defaultState: Factory for creating the initial state
    ///   - reducer: Pure function to transform state based on events
    ///   - persistenceKey: Optional key for persistence; if provided, enables state persistence
    ///   - dispatchFilter: Optional filter to control event processing
    public init(
        defaultState: @Sendable @escaping () -> AppState<Persistent, Transient>,
        persistenceKey: String? = nil,
        dispatchFilter: ((any AppEvent) async -> Bool)? = nil
    ) async {
        self.defaultState = defaultState
        if let persistenceKey {
            self.persistenceCoordinator = await PersistenceCoordinator(
                persistenceKey: persistenceKey)
        }
        else {
            self.persistenceCoordinator = nil
        }
        self.effectsCoordinator = EffectsCoordinator<Persistent, Transient>()
        self.listenerManager = ListenerManager<Persistent, Transient>()
        var initialState = defaultState()
        if let persistenceCoordinator {
            initialState.p = await persistenceCoordinator.loadInitialState() ?? initialState.p
        }
        self.stateBox = ManagedAtomic(StateBox(state: initialState))
        self.dispatchFilter = dispatchFilter

        // Ensure listeners/effects receive the initial state through normal event flow
        let initialEvent = StateRestoreEvent(restoredState: initialState.p)
        let stream = AsyncStream<EnqueuedEvent> { continuation in
            continuation.yield(EnqueuedEvent(event: initialEvent))
            self.continuation = continuation
        }
        var iterator = stream.makeAsyncIterator()
        // Wait for initial event received
        _ = await iterator.next()

        Task {
            await dispatch(initialEvent)
            await self.process(stream: stream)
        }
    }

    /// Sets the side effects to run after state updates
    /// - Parameter effects: Function to execute effects with event and new state
    public func setEffects(
        _ effects: (@Sendable (any AppEvent, AppState<Persistent, Transient>) async -> Void)?
    ) async {
        await effectsCoordinator.setEffects(effects)

    }

    /// Sets the dispatch filter for controlling event processing
    /// - Parameter filter: Function that returns true if event should be processed
    public func setDispatchFilter(_ filter: @escaping (any AppEvent) async -> Bool) {
        self.dispatchFilter = filter
    }

    /// Adds a weak listener that will be notified of state changes
    /// - Parameter listener: The object that implements StateListener
    public func addListener(_ listener: any StateListener) async {
        await listenerManager.addListener(listener)
        await listener.updateState(StateHolder(state: state))
    }
    public nonisolated func addListener(_ listener: any StateListener) {
        Task {
            await self.addListener(listener)
        }
    }

    public func addReducer(_ reducer: AnyReducer<AppState<Persistent, Transient>>) {
        reducers.append(reducer)

    }

    /// Processes events from the async stream
    private func process(stream: AsyncStream<EnqueuedEvent>) async {
        for await event in stream {
            await process(event: event)
        }
    }

    /// Processes a single event, updating state and running effects
    private func process(event: EnqueuedEvent) async {

        let previousState = state
        var resultingState = previousState
        // Handle special state events
        if event.event is ResetEvent {
            resultingState = self.defaultState()
        }
        else if let stateRestoreEvent = event.event as? StateRestoreEvent<Persistent> {
            resultingState.p = stateRestoreEvent.restoredState
        }
        else {
            for reducer in reducers {
                resultingState = reducer.reduce(state: resultingState, enqueuedEvent: event)
            }
        }
        stateBox.store(StateBox(state: resultingState), ordering: .relaxed)
        //        recordLayoutDebugIfNeeded(event: event, resultingState: resultingState)
        // Persist if persistence coordinator is provided
        await persistenceCoordinator?.saveStateIfNeeded(resultingState.p, for: event.event)
        // Execute effects
        await effectsCoordinator.executeEffects(for: event.event, state: resultingState)
        // Notify listeners of state change
        let stateHolder = StateHolder(state: resultingState)
        await listenerManager.notifyListeners(with: stateHolder)
        eventsProcessed += 1
    }

    /// Dispatches an event for processing, optionally bypassing filters
    /// This is the main entry point for triggering state changes
    /// - Parameters:
    ///   - event: The event to dispatch
    ///   - withoutFilter: If true, skips dispatch filtering
    public func dispatch(_ event: any AppEvent, withoutFilter: Bool = false) async {
        if !withoutFilter, let filter = dispatchFilter {
            if !(await filter(event)) {
                return  // Filtered out
            }
        }
        eventsDispatched += 1

        self.continuation?.yield(EnqueuedEvent(event: event))
    }

    nonisolated public func dispatch(_ event: any AppEvent, withoutFilter: Bool = false) {
        Task {
            await dispatch(event, withoutFilter: withoutFilter)
        }
    }

}
