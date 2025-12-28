import SwiftSyntaxMacros

/// Macro that generates ViewModel boilerplate for state management.
/// Adds stateManager property, dispatch method, and listener update logic.
/// Classes marked with @StateForwarder will automatically implement StateListener and observe state changes.
/// - Parameter stateType: The State type to use (optional, can be inferred).
/// ## Usage
/// ```swift
/// @StateForwarder(MyState.self)
/// class MyViewModel {
///     @Published var counter: Int = 0
/// }
/// ```
@attached(member, names: arbitrary)
public macro StateForwarder(
    for _: Any.Type,
    mapping _: Any
) = #externalMacro(module: "WaveMacrosPlugin", type: "StateForwarderMacro")
