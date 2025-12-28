import Foundation

/// Global event recorder for debugging and replay functionality.
/// Records events with timestamps and can replay them for testing.
@MainActor public class EventRecorder {
    /// Shared singleton instance
    public static let shared = EventRecorder()
    /// Recorded events with their timestamps
    var events: [(any AppEvent, Date)] = []
    /// Flag indicating if events are currently being replayed
    public var isReplaying = false

    /// Records an event with the current timestamp
    /// - Parameter event: The event to record
    public func record(_ event: any AppEvent) {

        events.append((event, Date()))
    }

    /// Returns all recorded events and clears the recording buffer
    /// - Returns: Array of recorded events with timestamps
    public func getAndClear() -> [(any AppEvent, Date)] {
        let copy = events
        events = []
        return copy
    }

    /// Clears all recorded events
    public func clear() {
        events = []
    }

    /// Dispatch filter that records events unless replaying
    /// - Parameter event: The event to potentially filter
    /// - Returns: True if event should be processed, false if filtered out
    public func dispatchFilter(event: any AppEvent) async -> Bool {
        if isReplaying {
            return false
        }
        record(event)
        return true
    }

    /// Replays recorded events with timing preservation.
    /// - Parameter dispatch: Function to dispatch each replayed event, with a flag indicating if it's the last event.
    /// - Note: Preserves relative timing between events. Use for testing or debugging.
    /// ## Usage
    /// ```swift
    /// await EventRecorder.shared.replay { event, isLast in
    ///     await stateManager.dispatch(event)
    ///     if isLast { print("Replay complete") }
    /// }
    /// ```
    public func replay(dispatch: @escaping (any AppEvent, Bool) async -> Void) async {
        let eventsToReplay = getAndClear()
        isReplaying = true
        defer { isReplaying = false }
        guard var lastTimestamp = eventsToReplay.first?.1 else { return }
        for (recordedEvent, timestamp) in eventsToReplay {
            if let recorderEvent = recordedEvent as? EventRecorderEvent, recorderEvent == .replay {
                break
            }
            let delta = timestamp.timeIntervalSince(lastTimestamp)
            lastTimestamp = timestamp
            if delta > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delta * 1_000_000_000))
            }

            await dispatch(recordedEvent, true)
        }
    }
}
