import Foundation
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
import WaveMacros
import WaveMacrosPlugin

func expandMacros(source: String, macros: [String: Macro.Type]) -> String {
    let sourceFile = Parser.parse(source: source)
    let context = BasicMacroExpansionContext()
    let expanded = sourceFile.expand(macros: macros, in: context)

    // 🔥 Print diagnostics emitted during macro expansion
    for diag in context.diagnostics {
        print("Macro diagnostic:", diag.message)
        print("  at:", diag.node.description)
    }

    return expanded.description
}

@Test("StateForwarder macro full text")
@MainActor
func testStateForwarderMacroExpansionFullText() throws {
    let macros: [String: Macro.Type] = [
        "StateForwarder": StateForwarderMacro.self
    ]
    let source = """
        @StateForwarder(for: StateObject.self,
            mapping: [(\\TestState.counter, \\StateObject.counter), (\\TestState.counter2, \\StateObject.counter2)])
        final class SampleViewModel {

        }
        """
    let expanded = expandMacros(source: source, macros: macros)
    print(expanded)
    let expected = """
        final class SampleViewModel {
            weak var receiver: StateObject?

            public var zombie: Bool {
                receiver == nil
            }

            let stateManager: AppUIStateManager

            public init(stateManager: AppUIStateManager) {
                self.stateManager = stateManager
                stateManager.addListener(self)
            }

            public func getStateObject() -> StateObject {
                let state = stateManager.getState()
                let so = StateObject(
                        counter: state[keyPath: \\TestState.counter],
                        counter2: state[keyPath: \\TestState.counter2]
                        )
                receiver = so
                return so
            }


            public func updateState(_ stateHolder: AnyObject) {
                guard let stateHolder = stateHolder as? AppStateHolder,
                    let receiver
                else {
                    return
                }

                let _forwardValue0 = stateHolder.state[keyPath: \\TestState.counter]
                let _forwardValue1 = stateHolder.state[keyPath: \\TestState.counter2]
                if receiver[keyPath: \\StateObject.counter] != _forwardValue0 {
                    receiver[keyPath: \\StateObject.counter] = _forwardValue0
                }
                if receiver[keyPath: \\StateObject.counter2] != _forwardValue1 {
                    receiver[keyPath: \\StateObject.counter2] = _forwardValue1
                }
            }
        }
        """
    let expandedLines = expanded.split(separator: "\n", omittingEmptySubsequences: false).map(
        String.init
    ).filter { !$0.isEmpty }
    let expectedLines = expected.split(separator: "\n", omittingEmptySubsequences: false).map(
        String.init
    ).filter { !$0.isEmpty }
    #expect(expandedLines.count == expectedLines.count)
    for (index, (expandedLine, expectedLine)) in zip(expandedLines, expectedLines).enumerated() {
        #expect(
            expandedLine == expectedLine,
            "Line \(index + 1) mismatch: expected '\(expectedLine)', got '\(expandedLine)'")
    }
}
