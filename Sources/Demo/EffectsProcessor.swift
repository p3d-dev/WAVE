// MARK: - Effects Processor
// PITFALL: Missing event processor - Without an effects processor, side effects (network, analytics, etc.) won't run.
// Handles side effects separately from UIStateManager for modularity and growth

import WaveState
import WaveViews

/// Handles side effects for the example application, such as initializing layout on app appearance.
/// Processes events and triggers additional actions like dispatching layout events.
@MainActor
class EffectsProcessor {
    private weak var stateManager: UIStateManager<ExamplePersistent, ExampleTransient>?

    init(stateManager: UIStateManager<ExamplePersistent, ExampleTransient>) {
        self.stateManager = stateManager
    }

    // This is in the processing loop => return as fast as possible !
    func process(event: any AppEvent, state: ExamplePersistent) async {
        // Handle example events
        if let exampleEvent = event as? ExampleEvent {
            await handleExample(event: exampleEvent, state: state)
        }

        // Handle replay
        if let eventRecorderEvent = event as? EventRecorderEvent, eventRecorderEvent == .replay {
            await handleReplay()
        }

        // Future: Add more effects here, e.g., analytics, network calls
    }

    private func handleExample(event: ExampleEvent, state: ExamplePersistent) async {
        switch event {
            default:
                break
        }
    }

    private func handleReplay() async {
        guard let stateManager = self.stateManager else { return }
        await EventRecorder.shared.replay(dispatch: stateManager.dispatch)
    }
}
