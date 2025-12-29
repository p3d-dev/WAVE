import Foundation

/// AppState represents the complete application state, separating persistent and transient data.
/// This generic struct ensures type safety and clear separation of concerns.
///
/// - Persistent: Data that survives app restarts (e.g., user preferences).
/// - Transient: Runtime-only data (e.g., UI measurements, temporary flags).
///
/// Design Decision: Generic over Persistent and Transient types for flexibility.
/// Conforms to Equatable for state comparison and Sendable for concurrency safety.
public struct AppState<
    Persistent: Codable & Equatable & Sendable,
    Transient: Equatable & Sendable
>: Equatable & Sendable {
    /// Transient state that is not persisted.
    public var t: Transient
    /// Persistent state that is saved to disk.
    public var p: Persistent

    /// Initializes the app state with persistent and transient components.
    /// - Parameters:
    ///   - t: The transient state.
    ///   - p: The persistent state.
    public init(t: Transient, p: Persistent) {
        self.t = t
        self.p = p
    }
}

/// StateHolder is a thread-safe container for application state.
/// It holds the current state and provides access for reading and updating.
/// State changes are propagated to listeners via the StateListener protocol.
///
/// Used by UIStateManager to provide observable state to SwiftUI views.
/// Providing stateHolder to the forwarder avoids copying
///
/// ## Usage
/// ```swift
/// let holder = StateHolder(state: MyState())
/// holder.state = newState  // State updated, listeners notified separately
/// ```
public final class StateHolder<
    Persistent: Codable & Equatable & Sendable,
    Transient: Equatable & Sendable
>: Sendable {
    /// The current application state.
    public let state: AppState<Persistent, Transient>

    /// Initializes the state holder with an initial state.
    /// - Parameter state: The initial state value.
    public init(state: AppState<Persistent, Transient>) {
        self.state = state
    }
}
