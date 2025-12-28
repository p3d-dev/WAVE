import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Compiler plugin that provides macros for Wave state management
@main
struct WaveMacrosPlugin: CompilerPlugin {
    /// The macros provided by this plugin
    let providingMacros: [Macro.Type] = [
        StateForwarderMacro.self
    ]
}

/// Errors that can occur during macro expansion
enum MacroError: Error {
    case message(String)
}

/// Macro that generates ViewModel implementation with state management
public struct StateForwarderMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.as(ClassDeclSyntax.self) != nil else {
            throw MacroError.message("@StateForwarder can only be used on classes")
        }

        let parsedArguments = try parseArguments(from: node)
        let forwards = parsedArguments.forwards
        let stateObjectType = parsedArguments.stateObjectType

        var generated: [DeclSyntax] = []
        generated.append(DeclSyntax("weak var receiver: \(raw: stateObjectType)?"))
        generated.append(DeclSyntax("public var zombie: Bool { receiver == nil }"))
        generated.append(
            DeclSyntax("let stateManager: AppUIStateManager")
        )
        generated.append(makeInitializer())
        generated.append(makeGetStateObject(stateObjectType: stateObjectType, forwards: forwards))
        generated.append(makeUpdateState(forwards: forwards))
        return generated
    }

    private struct ForwardDefinition {
        let stateKeyPath: String
        let objectKeyPath: String
        let objectPropertyName: String
    }

    private struct ParsedArguments {
        let stateObjectType: String
        let forwards: [ForwardDefinition]
    }

    private static func parseArguments(from attribute: AttributeSyntax) throws -> ParsedArguments {
        guard let arguments = attribute.arguments,
            case .argumentList(let argumentList) = arguments
        else {
            throw MacroError.message("@StateForwarder requires arguments")
        }

        var stateObjectType: String?
        var forwards: [ForwardDefinition] = []

        for argument in argumentList {
            let label = argument.label?.text
            if label == "for", stateObjectType == nil {
                stateObjectType = try parseTypeName(from: argument.expression)
            }
            else if label == "mapping" {
                forwards = try parseMapping(from: argument.expression)
            }
            else if label == nil {
                if stateObjectType == nil {
                    stateObjectType = try parseTypeName(from: argument.expression)
                }
                else if forwards.isEmpty {
                    forwards = try parseMapping(from: argument.expression)
                }
            }
        }

        guard let stateObjectType else {
            throw MacroError.message("@StateForwarder requires `for` type argument")
        }
        guard !forwards.isEmpty else {
            throw MacroError.message("@StateForwarder requires mapping")
        }

        return ParsedArguments(stateObjectType: stateObjectType, forwards: forwards)
    }

    private static func parseTypeName(from expression: ExprSyntax) throws -> String {
        var text = expression.trimmedDescription
        if text.hasSuffix(".self") {
            text.removeLast(5)
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw MacroError.message("@StateForwarder requires a valid type reference")
        }
        return text
    }

    private static func parseMapping(from expression: ExprSyntax) throws -> [ForwardDefinition] {
        guard let arrayExpr = expression.as(ArrayExprSyntax.self) else {
            throw MacroError.message("@StateForwarder mapping must be an array of tuples")
        }

        var forwards: [ForwardDefinition] = []
        for element in arrayExpr.elements {
            guard let tupleExpr = element.expression.as(TupleExprSyntax.self),
                tupleExpr.elements.count == 2,
                let stateExpr = tupleExpr.elements.first?.expression,
                let objectExpr = tupleExpr.elements.last?.expression
            else {
                throw MacroError.message("@StateForwarder mapping entries must be tuple pairs")
            }
            let stateKeyPath = stateExpr.trimmedDescription
            let objectKeyPath = objectExpr.trimmedDescription
            let propertyName = try keyPathPropertyName(from: objectKeyPath)
            forwards.append(
                .init(
                    stateKeyPath: stateKeyPath, objectKeyPath: objectKeyPath,
                    objectPropertyName: propertyName))
        }
        return forwards
    }

    private static func keyPathPropertyName(from keyPath: String) throws -> String {
        let components = keyPath.split(separator: ".")
        guard let lastComponent = components.last else {
            throw MacroError.message("Key path must include a property name")
        }
        return String(lastComponent)
    }

    private static func makeInitializer() -> DeclSyntax {
        DeclSyntax(
            """
            public init(stateManager: AppUIStateManager) {
                self.stateManager = stateManager
                stateManager.addListener(self)
            }
            """
        )
    }

    private static func makeGetStateObject(
        stateObjectType: String,
        forwards: [ForwardDefinition]
    ) -> DeclSyntax {
        let parameterLines = forwards.enumerated().map { index, forward -> String in
            let trailingComma = index < forwards.count - 1 ? "," : ""
            return
                "            \(forward.objectPropertyName): state[keyPath: \(forward.stateKeyPath)]\(trailingComma)"
        }.joined(separator: "\n")
        let initializerArguments = parameterLines.isEmpty ? "" : "\(parameterLines)\n"

        let body = """
            public func getStateObject() -> \(stateObjectType) {
                let state = stateManager.getState()
                let so = \(stateObjectType)(
            \(initializerArguments)            )
                receiver = so
                return so
            }
            """
        return DeclSyntax(stringLiteral: body)
    }

    private static func makeUpdateState(forwards: [ForwardDefinition]) -> DeclSyntax {
        var lines: [String] = [
            "public func updateState(_ stateHolder: AnyObject) {",
            "    guard let stateHolder = stateHolder as? AppStateHolder,",
            "        let receiver",
            "    else {",
            "        return",
            "    }",
            "",
        ]

        for (index, forward) in forwards.enumerated() {
            let tempName = "_forwardValue\(index)"
            lines.append(
                "    let \(tempName) = stateHolder.state[keyPath: \(forward.stateKeyPath)]"
            )
        }

        for (index, forward) in forwards.enumerated() {
            let tempName = "_forwardValue\(index)"
            lines.append("    if receiver[keyPath: \(forward.objectKeyPath)] != \(tempName) {")
            lines.append("        receiver[keyPath: \(forward.objectKeyPath)] = \(tempName)")
            lines.append("    }")
        }

        lines.append("}")

        return DeclSyntax(stringLiteral: lines.joined(separator: "\n"))
    }
}

extension AttributeSyntax {
    fileprivate func matchesIdentifier(_ name: String) -> Bool {
        guard let identifier = attributeName.as(IdentifierTypeSyntax.self) else {
            return false
        }
        return identifier.name.text == name
    }

    fileprivate var argumentExpression: ExprSyntax? {
        guard let arguments, case .argumentList(let argumentList) = arguments else {
            return nil
        }
        return argumentList.first?.expression
    }

    fileprivate var stateTypeArgument: TypeSyntax? {
        guard let arguments, case .argumentList(let argumentList) = arguments,
            let expression = argumentList.first?.expression
        else {
            return nil
        }
        var text = expression.trimmedDescription
        if text.hasSuffix(".self") {
            text.removeLast(5)
        }
        guard !text.isEmpty else {
            return nil
        }
        return TypeSyntax(stringLiteral: text)
    }
}

extension VariableDeclSyntax {
    fileprivate var forwardAttribute: AttributeSyntax? {
        for element in attributes {
            if case .attribute(let attribute) = element, attribute.matchesIdentifier("Forward") {
                return attribute
            }
        }
        return nil
    }

    fileprivate func hasAttribute(named name: String) -> Bool {
        for element in attributes {
            if case .attribute(let attribute) = element, attribute.matchesIdentifier(name) {
                return true
            }
        }
        return false
    }

    fileprivate func hasModifier(_ keyword: TokenKind) -> Bool {
        for modifier in modifiers {
            if modifier.name.tokenKind == keyword {
                return true
            }
        }
        return false
    }

    fileprivate var hasPrivateSetModifier: Bool {
        for modifier in modifiers {
            guard modifier.name.tokenKind == .keyword(.private),
                let detail = modifier.detail?.detail
            else {
                continue
            }
            if detail.tokenKind == .identifier("set") || detail.tokenKind == .keyword(.set) {
                return true
            }
        }
        return false
    }

}

extension TypeSyntax {
    fileprivate var trimmedDescription: String {
        self.trimmed.description
    }
}

extension ClassDeclSyntax {
    fileprivate var stateTypeAlias: TypeSyntax? {
        for member in memberBlock.members {
            guard let typealiasDecl = member.decl.as(TypeAliasDeclSyntax.self),
                typealiasDecl.name.text == "State"
            else {
                continue
            }
            return typealiasDecl.initializer.value
        }
        return nil
    }

    fileprivate var stateManagerPropertyType: TypeSyntax? {
        for member in memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in varDecl.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                    pattern.identifier.text == "stateManager",
                    let typeAnnotation = binding.typeAnnotation,
                    let identifierType = typeAnnotation.type.as(IdentifierTypeSyntax.self),
                    identifierType.name.text == "UIStateManager",
                    let argument = identifierType.genericArgumentClause?.arguments.first?.argument
                else {
                    continue
                }
                return argument
            }
        }
        return nil
    }

    fileprivate func hasProperty(named name: String) -> Bool {
        for member in memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in varDecl.bindings {
                if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                    pattern.identifier.text == name
                {
                    return true
                }
            }
        }
        return false
    }

    fileprivate func hasTypealias(named name: String) -> Bool {
        for member in memberBlock.members {
            guard let typealiasDecl = member.decl.as(TypeAliasDeclSyntax.self),
                typealiasDecl.name.text == name
            else {
                continue
            }
            return true
        }
        return false
    }

    fileprivate func hasFunction(named name: String) -> Bool {
        for member in memberBlock.members {
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }
            if funcDecl.name.text == name {
                return true
            }
        }
        return false
    }

    fileprivate var hasInitializer: Bool {
        for member in memberBlock.members {
            if member.decl.is(InitializerDeclSyntax.self) {
                return true
            }
        }
        return false
    }
}
