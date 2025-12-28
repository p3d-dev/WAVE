import SwiftUI
import WaveMacros
import WaveState
import WaveViews

/// Forwarder for EventStateObject to sync event logging state.
@StateForwarder(
    for: EventStateObject.self,
    mapping: [
        (\AppStateAlias.t.eventLogging.events, \EventStateObject.events),
    ]
)
public final class EventForwarder: StateListener {}