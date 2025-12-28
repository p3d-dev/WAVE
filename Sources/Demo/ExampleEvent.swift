import WaveViews

/// Events represent user actions or system responses that trigger state changes.
/// Replace 'ExampleEvent' with your feature's event enum name.
/// Use associated values for events that carry data (e.g., setCounter(Int)).
/// Implement AppEvent protocol for persistence and UI classification.
public enum ExampleEvent: AppEvent, Codable, Equatable {
    case onAppear
    case load
    case reset
    case incrementCounter
    case decrementCounter
    case setCounter(Int)
    case loaded(String)
    case loadError
    case replay

    public var persist: Bool {
        switch self {
            case .load, .loaded, .loadError, .reset, .incrementCounter, .decrementCounter,
                .setCounter:
                return true
            case .onAppear, .replay:
                return false
        }
    }

    public var isUIEvent: Bool {
        switch self {
            case .onAppear, .load, .reset, .incrementCounter, .decrementCounter, .setCounter:
                return true
            case .loaded, .loadError, .replay:
                return false
        }
    }
}
