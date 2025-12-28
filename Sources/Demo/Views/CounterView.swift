import SwiftUI

/// Pure views only observe state and render UI based on current values.
/// They do NOT dispatch events or handle user input.
/// Replace 'CounterView' with your feature's display component name.
/// Use @ObservedObject to react to state changes.
struct CounterView: View {
    @ObservedObject var stateObject: ExampleStateObject

    var body: some View {
        Text("Counter: \(stateObject.counter)")
    }
}
