import SwiftUI
import WaveViews

/// Replace 'ExampleState' with your feature's state name.
/// This represents the data that gets persisted across app launches.
/// Include only serializable properties (Codable, Equatable, Sendable).
/// Use default values for initial state.
/// If you need to define an interface protocol, add it above this struct.
public struct ExampleState: Equatable, Sendable, Codable {

    public var mode: ExampleMode = .idle
    public var counter: Int = 0

    public init() {}

    public init(mode: ExampleMode, counter: Int) {
        self.mode = mode
        self.counter = counter
    }
}
