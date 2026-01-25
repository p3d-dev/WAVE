import SwiftUI
import WaveState

/// Immutable entry describing a dispatched event for debugging purposes.
public struct EventEntry: Equatable, Sendable, Identifiable {
    public var id: UInt64 {
        self.timestamp
    }

    /// Timestamp captured from `DispatchTime.now().uptimeNanoseconds`.
    public let timestamp: UInt64
    /// The original event.
    public let event: any AppEvent
    /// Type name of the dispatched event.
    public let typeName: String
    /// Textual representation for quick inspection.
    public let description: String
    /// Indicates whether the event originated from the UI.
    public let isUIEvent: Bool
    /// Indicates whether the event triggered persistence.
    public let persist: Bool

    public static func == (lhs: EventEntry, rhs: EventEntry) -> Bool {
        lhs.timestamp == rhs.timestamp
            && lhs.typeName == rhs.typeName
            && lhs.description == rhs.description
            && lhs.isUIEvent == rhs.isUIEvent
            && lhs.persist == rhs.persist
    }

    /// Creates an entry based on the provided event.
    /// - Parameter EnqueuedEvent: The queued event being logged.
    public init(enqueuedEvent: EnqueuedEvent) {
        timestamp = enqueuedEvent.enqueuedAt
        event = enqueuedEvent.event
        typeName = String(reflecting: type(of: enqueuedEvent.event))
        description = String(describing: enqueuedEvent.event)
        isUIEvent = enqueuedEvent.event.isUIEvent
        persist = enqueuedEvent.event.persist
    }

    /// Creates a custom entry, primarily for testing or tooling.
    public init(
        timestamp: UInt64,
        event: any AppEvent,
        typeName: String,
        description: String,
        isUIEvent: Bool,
        persist: Bool
    ) {
        self.timestamp = timestamp
        self.event = event
        self.typeName = typeName
        self.description = description
        self.isUIEvent = isUIEvent
        self.persist = persist
    }
}
