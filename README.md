# 🌊 WAVE Architecture

**WAVE** is an application architecture for building interactive systems with a clean, deterministic flow.  
It stands for:

> **W**orld State, **A**ctions (Reducer & Effects), **V**iews with StateObjects, **E**vents and Dispatch

WAVE is inspired by MVI/Elm/Redux patterns but focuses on **clarity, separation of concerns**, and an intuitive lifecycle:  
**the world changes, actions ripple outward, views update, and new events feed back in.**

---

## Usage of the package

Add as a dependency:
```
.package(url: "https://github.com/p3d-dev/WAVE.git", .upToNextMajor(from: "1.0.0")),
```

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
- **Avoidance of SwiftUI hassles** - no mix-up of views and states
- **Fast, atomic reducers** run off the main thread for performance
- **Async effects** manage long-running tasks and feedback via events
- **Views and logic are independently testable** — views can be tested without business logic, and logic without UI concerns

WAVE helps build systems that are:
- easier to reason about
- simpler to test
- naturally scalable
- friendly to FP or OOP
- uses macros to avoid boilerplate code.

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

Then, define your app state by combining them. **Note: These typealias names must be used exactly as shown, as they are hardcoded in the macros.**

```swift
public typealias AppState = AppState<MyPersistent, MyTransient>
public typealias AppStateHolder = StateHolder<MyPersistent, MyTransient>
public typealias AppUIStateManager = UIStateManager<MyPersistent, MyTransient>
```

### Enabling Persistence

To enable automatic persistence of your app's state across app launches, provide a `persistenceKey` when initializing the `UIStateManager`. This key is used to store and retrieve the persistent state from `UserDefaults`.

```swift
        let stateManager = await AppUIStateManager(
            defaultState: { @Sendable in
                AppState(t: MyTransient(), p: MyPersistent())
            },
            persistenceKey: "myAppState"  // Enables persistence with this key
        )
        await stateManager.addReducer(
            AnyReducer<AppState>(MyReducer())
        )
```

- **persistenceKey**: A unique string identifier for storing your app's persistent state. If provided, the state manager will automatically save and restore persistent state. If omitted, persistence is disabled and state resets on each app launch.

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
    func reduce(state: AppState, queuedEvent: QueuedEvent) -> AppState {
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

The definition of MyStateObject belongs to a view definition, because a view needs it. The Listener belongs to app/app state code, which forwards from state (single truth) to StateObject

Use `@StateForwarder` macro to automatically sync app state with SwiftUI `ObservableObject`s. Define mappings from app state key paths to object properties.

Define the StateObject in your view files:

```swift
import SwiftUI

public final class MyStateObject: ObservableObject {
    @Published public var counter: Int
    @Published public var mode: MyMode

    public init(counter: Int = 0, mode: MyMode = .idle) {
        self.counter = counter
        self.mode = mode
    }
}
```

Define the Forwarder in your app state code:

```swift
import WaveState
import WaveMacros

@StateForwarder(
    for: MyStateObject.self,
    mapping: [
        (\AppState.p.counter, \MyStateObject.counter),
        (\AppState.p.mode, \MyStateObject.mode),
    ]
)
public final class MyForwarder: StateListener {}
```

Use the StateObject in a view:

```swift
import SwiftUI
import WaveViews

public struct MyView: View {
    @StateObject var stateObject: MyStateObject
    @Environment(\.appDispatch) private var appDispatch: AppDispatch

    public var body: some View {
        Text("Counter: \(stateObject.counter)")
        Button("Increment") {
            appDispatch(MyEvent.incrementCounter)
        }
    }
}
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

### Using the Object Factory

Use the object factory to create StateObjects that automatically sync with app state. Access the factory via `@Environment(\.objectFactory)` and call `makeStateObject()` to get properly initialized StateObjects.

```swift
import SwiftUI
import WaveViews

public struct MyLayoutView: View {
    @Environment(\.objectFactory) private var objectFactory

    public var body: some View {
        if let stateObject: MyStateObject = objectFactory?.makeStateObject() {
            MyView(stateObject: stateObject)
        } else {
            Text("Loading...")
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

    private var sliderBinding: Binding<Float> { makeBinding(
        get: { Float(stateObject.counter) },
        send: { appDispatch(MyEvent.setCounter(Int($0))) })
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
    @State var stateManager: AppUIStateManager?

    func initializeStateManager() async -> AppUIStateManager {
        let stateManager = await AppUIStateManager(
            defaultState: { @Sendable in
                AppState(t: MyTransient(), p: MyPersistent())
            },
            persistenceKey: "myAppState"  // Optional: enables state persistence
        )
        await stateManager.addReducer(
            AnyReducer<AppState>(MyReducer())
        )
        return stateManager
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let stateManager {
                    MyLayoutView()
                        .environment(
                            \.appDispatch,
                            { @Sendable event in stateManager.dispatch(event) }
                        )
                        .environment(
                            \.objectFactory,
                            MyStateObjectFactory(stateManager: stateManager)
                        )
                }
            }
            .onAppear {
                Task {
                    stateManager = await initializeStateManager()
                }
            }
        }
    }
}
```

