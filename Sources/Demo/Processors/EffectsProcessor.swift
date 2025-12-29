// MARK: - Effects Processor
// PITFALL: Missing event processor - Without an effects processor, side effects (network, analytics, etc.) won't run.
// Handles side effects separately from UIStateManager for modularity and growth

import Foundation
import WaveState
import WaveViews

/// Handles side effects for the example application, such as initializing layout on app appearance.
/// Processes events and triggers additional actions like dispatching layout events.
@MainActor
public class EffectsProcessor {
    private weak var stateManager: AppUIStateManager?

    public init(stateManager: AppUIStateManager) {
        self.stateManager = stateManager
    }

    // This is in the processing loop => return as fast as possible !
    public func process(event: any AppEvent, state: AppStateAlias) async {
        // Handle example events
        if event is ExampleEvent {
            // No side effects for example events currently
        }

        // Handle replay
        if let eventLoggingEvent = event as? EventLoggingEvent, eventLoggingEvent == .replay {
            await handleReplay(state: state)
        }

        // Future: Add more effects here, e.g., analytics, network calls
    }

    private func handleReplay(state: AppStateAlias) async {
        guard let stateManager = self.stateManager else { return }
        let eventsToReplay = state.t.eventLogging.events.map { $0.event }
        Task.detached {
            await stateManager.dispatch(EventLoggingEvent.clear)
            for event in eventsToReplay {
                try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
                await stateManager.dispatch(event)
            }
        }
    }
}
