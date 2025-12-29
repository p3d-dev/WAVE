// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "WAVE",
    platforms: [
        .iOS(.v15),
        .macOS(.v15),
        .tvOS(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "WaveMacros", targets: ["WaveMacros"]),
        .library(name: "WaveViews", targets: ["WaveViews"]),
        .library(name: "WaveState", targets: ["WaveState"]),
        .library(name: "WaveDemo", targets: ["WaveDemo"]),
        .executable(name: "Demo", targets: ["Demo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.3.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .macro(
            name: "WaveMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            path: "Macros/WaveMacrosPlugin"
        ),
        .target(
            name: "WaveMacros",
            dependencies: [
                "WaveMacrosPlugin",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ],
            path: "Macros/WaveMacros"
        ),
        .target(
            name: "WaveViews",
            path: "Sources/WaveViews"
        ),
        .target(
            name: "WaveState",
            dependencies: [
                "WaveViews",
                .product(name: "Atomics", package: "swift-atomics"),
            ],
            path: "Sources/WaveState"
        ),
        .testTarget(
            name: "WaveMacrosTests",
            dependencies: [
                "WaveMacros",
                "WaveMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "WaveStateTests",
            dependencies: ["WaveState"]
        ),
        .target(
            name: "WaveDemo",
            dependencies: ["WaveState", "WaveMacros"],
            path: "Sources/Demo",
            exclude: ["App"]
        ),
        .executableTarget(
            name: "Demo",
            dependencies: ["WaveDemo"],
            path: "Sources/Demo/App"
        ),
        .testTarget(
            name: "DemoTests",
            dependencies: ["WaveDemo"]
        ),
    ]
)
