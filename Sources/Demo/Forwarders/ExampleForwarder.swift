import SwiftUI
import WaveMacros
import WaveState
import WaveViews

/// Replace 'ExampleForwarder' with your feature's forwarder name.
/// The @StateForwarder macro automatically generates code to sync app state with StateObjects.
/// Use key paths to map persistent/transient state properties to StateObject properties.
/// This enables reactive UI updates when state changes.
@StateForwarder(
    for: ExampleStateObject.self,
    mapping: [
        // Use \AppStateAlias.p for persistent state, \AppStateAlias.t for transient
        (\AppStateAlias.p.exampleState.counter, \ExampleStateObject.counter),
        (\AppStateAlias.p.exampleState.mode, \ExampleStateObject.mode),
    ]
)
public final class ExampleForwarder: StateListener {}
