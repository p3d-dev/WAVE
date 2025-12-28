import SwiftUI
import WaveViews

/// Active elements handle user interactions and trigger state changes via events.
/// They use @Environment(\.appDispatch) to send events to the reducer.
/// Replace 'CounterSliderView' with your feature's interactive component name.
/// Use Bindings to connect UI controls to state while dispatching events on changes.
struct CounterSliderView: View {
    @ObservedObject var stateObject: ExampleStateObject
    @Environment(\.appDispatch) private var appDispatch: AppDispatch

    private var x: Binding<Float> { makeBinding(
        get: { Float(stateObject.counter) },
        send: { appDispatch(ExampleEvent.setCounter(Int($0))) })
    }

    var body: some View {
        Slider(
            value: x, in: 0...100,
            label: {
                Text("Counter: \(x.wrappedValue)")
            })
    }
}
