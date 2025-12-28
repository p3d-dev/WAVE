# 🌊 WAVE Architecture

**WAVE** is an application architecture for building interactive systems with a clean, deterministic flow.  
It stands for:

> **W**orld State, **A**ctions (Reducer & Effects), **V**iews with StateObjects, **E**vents and Dispatch

WAVE is inspired by MVI/Elm/Redux patterns but focuses on **clarity, separation of concerns**, and an intuitive lifecycle:  
**the world changes, actions ripple outward, views update, and new events feed back in.**

---

## 🏃 Running the Demo

To run the included demo app, use:

```bash
swift run
```

---

## 🛠️ Code Formatting and Linting

This project uses [swift-format](https://github.com/apple/swift-format) for code formatting and linting.

To lint the code for style issues:

```bash
swift format lint --recursive .
```

To automatically format the code:

```bash
swift format --recursive --in-place .
```

Or using the short form:

```bash
swift format -ri .
```

Ensure your code adheres to the style guidelines defined in `.swift-format` before committing.

---

## 📦 Module Structure

WAVE is split into two modules for optimal separation of concerns:

- **WaveViews**: Minimal utilities for pure views. Provides environment keys for dispatching events and creating SwiftUI bindings. Views remain stateless and event-agnostic by design.
- **WaveState**: Full state management engine, including reducers, persistence, effects, listeners, and event protocols. Import alongside `WaveMacros` for ViewModel generation.

Pure views import only `WaveViews`; app logic imports `WaveState` (which re-exports `WaveViews` for convenience).

---

## 🚀 Why WAVE?

- **Unidirectional & predictable** data flow  
- **Idempotent World updates** keep logic stable and testable  
- **Explicit Actions** handle external side-effects safely  
- **Presentation layers stay pure** (no domain logic leaks)  
- **Events drive everything** — no hidden state magic
- **Avoidance of SwiftUI hazzles** - no mix up of views and states
- **Fast, atomic reducers** run off the main thread for performance
- **Async effects** manage long-running tasks and feedback via events
- **Views and logic are independently testable** — views can be tested without business logic, and logic without UI concerns

WAVE helps build systems that are:
- easier to reason about
- simpler to test
- naturally scalable
- friendly to FP or OOP
- uses macros to avoid boiler plate code.

---

## 📝 Usage

### Defining State

WAVE separates application state into **persistent** and **transient** components:

- **Persistent state**: Data that survives app restarts (user preferences, saved data). Conforms to `PersistentState` (which includes `Codable`, `Equatable`, `Sendable`).
- **Transient state**: Runtime-only data (UI state, temporary flags). Conforms to `Equatable` and `Sendable`.

Define your persistent and transient states separately:

```swift
import WaveState

public struct MyPersistent: PersistentState {
    public var counter: Int = 0
    public var mode: MyMode = .idle

    public init() {}
}

public struct MyTransient: Equatable, Sendable {
    public init() {}
}
```

Then, define your app state by combining them:

```swift
public typealias MyAppState = AppState<MyPersistent, MyTransient>
public typealias MyAppUIStateManager = UIStateManager<MyPersistent, MyTransient>
```

### Handling Events

Create an enum for events that implements `AppEvent`. Define cases for user actions and system responses. Specify which events should persist and which are UI events.

```swift
import WaveViews

public enum MyEvent: AppEvent, Codable, Equatable {
    case incrementCounter
    case decrementCounter
    case setCounter(Int)

    public var persist: Bool {
        switch self {
        case .incrementCounter, .decrementCounter, .setCounter:
            return true
        }
    }

    public var isUIEvent: Bool {
        switch self {
        case .incrementCounter, .decrementCounter, .setCounter:
            return true
        }
    }
}
```

### Creating a Reducer

Implement a reducer as a pure function that transforms state based on events. Return new state instances without mutating the input.

```swift
import WaveState

struct MyReducer: EventReducer {
    func reduce(state: MyAppState, queuedEvent: QueuedEvent) -> MyAppState {
        var newState = state
        let event = queuedEvent.event
        if let myEvent = event as? MyEvent {
            switch myEvent {
            case .incrementCounter:
                newState.p.counter += 1
            case .decrementCounter:
                newState.p.counter -= 1
            case .setCounter(let value):
                newState.p.counter = value
            }
        }
        return newState
    }
}
```

### State Objects and Forwarders

Use `@StateForwarder` macro to automatically sync app state with SwiftUI `ObservableObject`s. Define mappings from app state key paths to object properties.

```swift
import WaveState
import WaveMacros
import WaveViews
import SwiftUI

public final class MyStateObject: ObservableObject {
    @Published public var counter: Int
    @Published public var mode: MyMode

    public init(counter: Int = 0, mode: MyMode = .idle) {
        self.counter = counter
        self.mode = mode
    }
}

@StateForwarder(
    for: MyStateObject.self,
    mapping: [
        (\MyAppState.p.counter, \MyStateObject.counter),
        (\MyAppState.p.mode, \MyStateObject.mode),
    ]
)
public final class MyForwarder: StateListener {}
```

### Building Views

Compose views using `@StateObject` for reactive state and `@Environment(\.appDispatch)` to send events. Keep views pure and stateless.

```swift
import SwiftUI
import WaveViews

public struct MyView: View {
    @StateObject var stateObject: MyStateObject
    @Environment(\.appDispatch) private var appDispatch: AppDispatch

    public init(stateObject: MyStateObject) {
        self._stateObject = StateObject(wrappedValue: stateObject)
    }

    public var body: some View {
        VStack {
            Text("Counter: \(stateObject.counter)")
            HStack {
                Button("-") {
                    appDispatch(MyEvent.decrementCounter)
                }
                Button("+") {
                    appDispatch(MyEvent.incrementCounter)
                }
            }
        }
    }
}
```

### Using Bindings

Use `makeBinding` to create SwiftUI bindings that dispatch events on changes. This connects UI controls to state reactively.

```swift
import SwiftUI
import WaveViews

struct MySliderView: View {
    @ObservedObject var stateObject: MyStateObject
    @Environment(\.appDispatch) private var appDispatch: AppDispatch

    private var sliderBinding: Binding<Float> {
        makeBinding(
            get: { Float(stateObject.counter) },
            send: { newValue in
                appDispatch(MyEvent.setCounter(Int(newValue)))
            }
        )
    }

    var body: some View {
        Slider(value: sliderBinding, in: 0...100)
    }
}
```

### Setting Up the App

Initialize the state manager, add reducers, and configure effects. Provide the dispatch function and object factory via environment.

```swift
import WaveState
import WaveViews
import SwiftUI

@main
struct MyApp: App {
    @State var stateManager: MyAppUIStateManager?

    var body: some Scene {
        WindowGroup {
            if let stateManager {
                MyView(stateObject: MyStateObject())
                    .environment(
                        \.appDispatch,
                        { @Sendable event in stateManager.dispatch(event) }
                    )
                    .environment(
                        \.objectFactory,
                        MyStateObjectFactory(stateManager: stateManager)
                    )
            } else {
                Text("Loading...")
                    .onAppear {
                        Task {
                            stateManager = await MyAppUIStateManager(
                                defaultState: { @Sendable in
                                    MyAppState(t: MyTransient(), p: MyPersistent())
                                }
                            )
                            await stateManager?.addReducer(
                                AnyReducer<MyAppState>(MyReducer())
                            )
                        }
                    }
            }
        }
    }
}
```

