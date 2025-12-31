import Foundation
import WaveState

/// Handles side effects for event logging, such as replaying events.
@MainActor
public class EventEffectsProcessor<Persistent, Transient>
where Persistent: PersistentState, Transient: Equatable & Sendable {
    private weak var stateManager: UIStateManager<Persistent, Transient>?
    private let replayDelay: UInt64  // in nanoseconds

    public init(stateManager: UIStateManager<Persistent, Transient>, replayDelay: Double = 0.5) {
        self.stateManager = stateManager
        self.replayDelay = UInt64(replayDelay * 1_000_000_000)
    }

    // This is in the processing loop => return as fast as possible!
    public func process(event: any AppEvent, events: [EventEntry]) async {
        // Handle replay
        if let eventLoggingEvent = event as? EventLoggingEvent, eventLoggingEvent == .replay {
            await handleReplay(events: events)
        }
    }

    private func handleReplay(events: [EventEntry]) async {
        guard let stateManager = self.stateManager else { return }
        let eventsToReplay = events.map { $0.event }
        Task.detached {
            await stateManager.dispatch(EventLoggingEvent.clear)
            for event in eventsToReplay {
                try? await Task.sleep(nanoseconds: self.replayDelay)
                await stateManager.dispatch(event)
            }
        }
    }
}