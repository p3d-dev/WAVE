import Testing
import WaveState
import WaveViews

@testable import Demo

private enum LoggingTestEvent: AppEvent, Equatable {
    case alpha
    case beta

    var persist: Bool { true }
    var isUIEvent: Bool { false }
}

@Test("EventLoggingReducer stores events with retention limit")
func testEventLoggingReducerRetainsEntries() {
    var loggingState = EventLoggingState()
    let reducer = EventLoggingReducer(maxEntries: 2)

    loggingState = reducer.reduce(
        state: loggingState,
        queuedEvent: QueuedEvent(event: LoggingTestEvent.alpha))
    #expect(loggingState.events.count == 1)
    #expect(loggingState.events.last?.typeName.contains("LoggingTestEvent") == true)

    loggingState = reducer.reduce(
        state: loggingState,
        queuedEvent: QueuedEvent(event: LoggingTestEvent.beta))
    #expect(loggingState.events.count == 2)

    loggingState = reducer.reduce(
        state: loggingState,
        queuedEvent: QueuedEvent(event: LoggingTestEvent.alpha))
    #expect(loggingState.events.count == 2)
    #expect(loggingState.events.first?.description.contains("beta") == true)
    #expect(loggingState.events.last?.description.contains("alpha") == true)
}
