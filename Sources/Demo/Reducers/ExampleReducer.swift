import WaveState

/// Reducers are pure functions that transform state based on events.
/// They return new state instances without mutating the input.
/// Replace 'ExampleReducer' with your feature's reducer name.
/// Implement EventReducer protocol for integration with UIStateManager.
public struct ExampleReducer: EventReducer {
    public init() {}

    public func reduce(state: AppStateAlias, enqueuedEvent: EnqueuedEvent) -> AppStateAlias {
        var newState = state
        let event = enqueuedEvent.event
        if let exampleEvent = event as? ExampleEvent {
            switch exampleEvent {
                case .onAppear:
                    break
                case .load:
                    newState.p.exampleState.mode = .loading
                case .loaded(let data):
                    newState.p.exampleState.mode = .loaded(data)
                case .loadError:
                    newState.p.exampleState.mode = .error
                case .reset:
                    newState.p.exampleState.counter = 0
                    newState.p.exampleState.mode = .idle
                case .incrementCounter:
                    newState.p.exampleState.counter += 1
                case .decrementCounter:
                    newState.p.exampleState.counter -= 1
                case .setCounter(let counter):
                    newState.p.exampleState.counter = counter
            }
        }
        return newState
    }
}
