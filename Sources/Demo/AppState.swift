import SwiftUI
import WaveState
import WaveViews

public typealias AppStateAlias = AppState<ExamplePersistent, ExampleTransient>
public typealias AppUIStateManager = UIStateManager<ExamplePersistent, ExampleTransient>
public typealias AppStateHolder = StateHolder<ExamplePersistent, ExampleTransient>

/// Transient state for example app, containing UI measurements
public struct ExampleTransient: Equatable, Sendable {
    public var eventLogging: EventLoggingState
    public var colorThemeSelectorColumns: Int

    public init() {
        eventLogging = EventLoggingState()
        colorThemeSelectorColumns = 3
    }
}

public struct ExamplePersistent: PersistentState {
    public var version: Int = 1
    public var exampleState: ExampleState

    public init() {
        exampleState = ExampleState()
    }
}
