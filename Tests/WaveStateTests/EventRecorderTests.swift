import Testing

@testable import WaveState

// Simple test state and event
struct TestState: PersistentState {
    var version: Int = 1
    var counter = 0
}

enum TestEvent: AppEvent, Equatable {
    case increment
    case reset

    var persist: Bool { true }
    var isUIEvent: Bool { true }
}

struct TestReducer: EventReducer {
    typealias State = AppState<TestState, EmptyTransient>

    func reduce(state: State, queuedEvent: QueuedEvent) -> State {
        var newState = state
        guard let event = queuedEvent.event as? TestEvent else { return newState }
        switch event {
            case .increment:
                newState.p.counter += 1
            case .reset:
                newState.p.counter = 0
        }
        return newState
    }
}

@Test("EventRecorder records and replays events")
@MainActor
func testEventRecorderRecordsAndReplays() async {
    let recorder = EventRecorder()
    let stateManager = await UIStateManager<TestState, EmptyTransient>(
        defaultState: { AppState(t: EmptyTransient(), p: TestState(counter: 0)) }
    )
    await stateManager.addReducer(AnyReducer(TestReducer()))

    // Set filter to record
    await stateManager.setDispatchFilter(recorder.dispatchFilter)

    // Dispatch some events
    await stateManager.dispatch(TestEvent.increment)
    await stateManager.dispatch(TestEvent.increment)
    await stateManager.debugWaitForEventsProcessed()

    // Check state
    #expect(stateManager.getState().p.counter == 2)

    // Replay events on a fresh stateManager
    let freshStateManager = await UIStateManager<TestState, EmptyTransient>(
        defaultState: { AppState(t: EmptyTransient(), p: TestState(counter: 0)) }
    )
    await freshStateManager.addReducer(AnyReducer(TestReducer()))

    await recorder.replay(dispatch: freshStateManager.dispatch)
    await freshStateManager.debugWaitForEventsProcessed()

    #expect(freshStateManager.getState().p.counter == 2)
}

@Test("EventRecorder dispatch filter")
@MainActor
func testEventRecorderDispatchFilter() async {
    let recorder = EventRecorder()
    let stateManager = await UIStateManager<TestState, EmptyTransient>(
        defaultState: { AppState(t: EmptyTransient(), p: TestState(counter: 0)) }
    )
    await stateManager.addReducer(AnyReducer(TestReducer()))

    // Set filter to record
    await stateManager.setDispatchFilter(recorder.dispatchFilter)

    // Dispatch event
    await stateManager.dispatch(TestEvent.increment)
    await stateManager.debugWaitForEventsProcessed()

    // Check that event was recorded
    let recorded = recorder.getAndClear()
    #expect(recorded.contains { ($0.0 as? TestEvent) == .increment })
}
