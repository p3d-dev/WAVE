import SwiftUI
import WaveViews
import WaveState

/// Replace 'ExampleMode' with your feature's state modes (e.g., idle, loading, success, error).
public enum ExampleMode: Equatable, Sendable, Codable {
    case idle
    case loading
    case loaded(String)
    case error
}

/// This demonstrates the ObservableObject pattern for SwiftUI state binding.
/// Replace 'ExampleStateObject' with your feature's state object name.
/// Use @Published for properties that trigger UI updates.
public final class ExampleStateObject: ObservableObject {
    @Published public var counter: Int
    @Published public var mode: ExampleMode

    public init(counter: Int = 0, mode: ExampleMode = .idle) {
        self.counter = counter
        self.mode = mode
        print("ExampleStateObject created")
    }
    deinit {
        print("ExampleStateObject deinit")
    }
}

/// This demonstrates the composition of pure views and active elements.
/// Pure views (like CounterView) only display state.
/// Active elements (like CounterSliderView and Buttons) dispatch events to update state.
/// Replace 'ExampleView' with your feature's main view name.
public struct ExampleView: View {
    @StateObject var stateObject: ExampleStateObject
    @Environment(\.appDispatch) private var appDispatch: AppDispatch

    public init(stateObject: ExampleStateObject) {
        self._stateObject = StateObject(wrappedValue: stateObject)
    }

    public var body: some View {
        VStack {
            CounterView(stateObject: stateObject)

            CounterSliderView(stateObject: stateObject)

            HStack {
                Button("-") {
                    appDispatch(ExampleEvent.decrementCounter)
                }
                Button("+") {
                    appDispatch(ExampleEvent.incrementCounter)
                }
            }

            switch stateObject.mode {
                case .idle:
                    Text("Title")

                    Button("Load") {
                        appDispatch(ExampleEvent.load)
                    }
                    Button("Simulate Error") {
                        appDispatch(ExampleEvent.loadError)
                    }
                case .loading:
                    ProgressView("Loading...")
                case .loaded(let data):
                    Text(data)
                case .error:
                    Text("Error")
            }

            Button("Reset") {
                appDispatch(ExampleEvent.reset)
            }
        }
        .onAppear {
            appDispatch(ExampleEvent.onAppear)
        }
    }
}
