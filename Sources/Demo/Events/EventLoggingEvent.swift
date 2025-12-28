import Foundation
import WaveViews

/// Events related to event logging and replay for debugging.
public enum EventLoggingEvent: AppEvent {
    /// Trigger replay of recorded events.
    case replay
    /// Clear the event log.
    case clear

    /// Logging events should not be persisted.
    public var persist: Bool { false }
    /// Logging events are not UI events.
    public var isUIEvent: Bool { false }
}
