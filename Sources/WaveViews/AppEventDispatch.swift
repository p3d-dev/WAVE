//  AppEventDispatch.swift
//
import SwiftUI

/// Protocol for events that can be dispatched to update application state.
/// Events are used in a unidirectional data flow pattern.
public protocol AppEvent: Sendable, Codable {
    /// Whether this event should trigger state persistence
    var persist: Bool { get }
    /// Whether this event originates from user interaction (UI event)
    var isUIEvent: Bool { get }
}

/// Type alias for the dispatch function used throughout the app.
/// This is the function signature that views use to send events to the state manager.
/// Views access this via @Environment(\.appDispatch) and call it to dispatch events.
public typealias AppDispatch = (@Sendable (any AppEvent) -> Void)

/// Environment key for injecting the app dispatch function.
/// This allows any view in the hierarchy to dispatch events without prop drilling.
/// Set this at the app level using .environment(\.appDispatch, { event in stateManager.dispatch(event) })
public struct AppDispatchKey: EnvironmentKey {
    public static let defaultValue: AppDispatch = { _ in }
}

extension EnvironmentValues {
    /// Accessor for the app dispatch function.
    /// Use @Environment(\.appDispatch) in views to get the dispatch closure.
    /// Call this function to send events: appDispatch(MyEvent.someEvent)
    public var appDispatch: AppDispatch {
        get { self[AppDispatchKey.self] }
        set { self[AppDispatchKey.self] = newValue }
    }
}

/// Protocol for factories that create StateObjects.
/// Implement this to provide StateObjects that are automatically synced with app state.
/// Views access the factory via @Environment(\.objectFactory)
public protocol StateObjectFactory: Sendable {
    @MainActor
    func makeStateObject<T>() -> StateObject<T>?
}

/// Environment key for injecting the StateObject factory.
/// This allows views to request StateObjects without knowing about the state manager.
/// Set this at the app level using .environment(\.objectFactory, MyFactory(stateManager: stateManager))
public struct StateObjectFactoryKey: EnvironmentKey {
    public static let defaultValue: (any StateObjectFactory)? = nil
}

extension EnvironmentValues {
    /// Accessor for the StateObject factory.
    /// Use @Environment(\.objectFactory) in views to get StateObjects.
    /// Call objectFactory?.makeStateObject() to get a properly initialized StateObject.
    public var objectFactory: (any StateObjectFactory)? {
        get { self[StateObjectFactoryKey.self] }
        set { self[StateObjectFactoryKey.self] = newValue }
    }
}

// Binding generator allowing dispatching of events on change
@MainActor
public func makeBinding<T: Equatable & Sendable>(
    get: @escaping () -> T, send: @escaping (T) -> Void
)
    -> Binding<T>
{
    .init(
        get: {
            get()
        },
        set: { newValue in
            if newValue == get() { return }
            send(newValue)
        }
    )
}
