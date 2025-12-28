import Foundation
import Testing
import WaveState

// Test state for persistence
struct PersistenceTestState: PersistentState {
    var version: Int = 1
    var counter: Int
    var name: String
}

// Config struct for demonstration
struct Config: Codable, Equatable, Sendable {
    var theme: String
    var enabled: Bool

    init(theme: String = "default", enabled: Bool = true) {
        self.theme = theme
        self.enabled = enabled
    }
}

// Version 1 state: initial version with counter and name
struct Version1State: PersistentState {
    var version: Int = 1
    var counter: Int
    var name: String
}

// Version 2 state: adds config struct with defaults
struct Version2State: PersistentState {
    var version: Int
    var counter: Int
    var name: String
    var config: Config

    init(counter: Int = 0, name: String = "", version: Int = 2, config: Config = Config()) {
        self.counter = counter
        self.name = name
        self.version = version
        self.config = config
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        counter = try container.decodeIfPresent(Int.self, forKey: .counter) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        version = 2  // Always current version
        config = try container.decodeIfPresent(Config.self, forKey: .config) ?? Config()
    }
}

// Version 3 state: removes config (keeps version)
struct Version3State: PersistentState {
    var version: Int
    var counter: Int
    var name: String

    init(version: Int = 3, counter: Int, name: String) {
        self.version = version
        self.counter = counter
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        counter = try container.decode(Int.self, forKey: .counter)
        name = try container.decode(String.self, forKey: .name)
        version = 3  // Always current version
    }
}

@Test @MainActor
func testPersistenceManagerLoadEmpty() async {
    let manager = PersistenceManager<PersistenceTestState>(persistenceKey: "testKey_\(UUID())")
    let loaded = manager.loadState()
    #expect(loaded == nil)
}

@Test @MainActor
func testPersistenceManagerSaveAndLoad() async {
    let key = "testKey_\(UUID())"
    let manager = PersistenceManager<PersistenceTestState>(persistenceKey: key)
    let state = PersistenceTestState(counter: 42, name: "test")

    await manager.saveStateIfNeeded(state, for: PersistenceTestEvent.persistTrue)
    await manager.flushPendingSaves()
    let loaded = manager.loadState()
    #expect(loaded == state)
}

@Test @MainActor
func testPersistenceManagerNoPersistEvent() async {
    let key = "testKey_\(UUID())"
    let manager = PersistenceManager<PersistenceTestState>(persistenceKey: key)
    let state = PersistenceTestState(counter: 42, name: "test")

    await manager.saveStateIfNeeded(state, for: PersistenceTestEvent.persistFalse)
    await manager.flushPendingSaves()
    let loaded = manager.loadState()
    #expect(loaded == nil)
}

@Test @MainActor
func testPersistenceManagerSaveImmediately() async {
    let key = "testKey_\(UUID())"
    let manager = PersistenceManager<PersistenceTestState>(persistenceKey: key)
    let state = PersistenceTestState(counter: 100, name: "immediate")

    manager.saveStateImmediately(state)

    let loaded = manager.loadState()
    #expect(loaded == state)
}

@Test @MainActor
func testPersistenceManagerDebounce() async {
    let key = "testKey_\(UUID())"
    let manager = PersistenceManager<PersistenceTestState>(persistenceKey: key)

    // Save multiple times quickly
    await manager.saveStateIfNeeded(
        PersistenceTestState(counter: 1, name: "first"), for: PersistenceTestEvent.persistTrue)
    await manager.saveStateIfNeeded(
        PersistenceTestState(counter: 2, name: "second"), for: PersistenceTestEvent.persistTrue)
    await manager.saveStateIfNeeded(
        PersistenceTestState(counter: 3, name: "third"), for: PersistenceTestEvent.persistTrue)

    // Immediately after rapid saves, data should still be pending
    let loadedEarly = manager.loadState()
    #expect(loadedEarly == nil)

    await manager.flushPendingSaves()

    let loaded = manager.loadState()
    #expect(loaded?.counter == 3)  // Last one should be saved
}

/// Tests loading corrupted data from persistence.
/// - Purpose: Verifies that corrupted or invalid data in UserDefaults is handled gracefully by returning nil.
/// - User Story: As a user, I expect the app to recover from corrupted settings without crashing.
@Test @MainActor
func testPersistenceManagerLoadCorruptedData() async {
    let key = "testKey_\(UUID())"
    let manager = PersistenceManager<PersistenceTestState>(persistenceKey: key)

    // Manually set corrupted data in UserDefaults
    UserDefaults.standard.set("invalid json", forKey: key)

    let loaded = manager.loadState()
    #expect(loaded == nil)  // Should return nil on decode failure
}

/// Tests backward compatibility: loading Version 1 data into Version 2 struct.
/// Version 2 adds properties (including a struct) with defaults for missing keys.
@Test @MainActor
func testPersistenceManagerVersionEvolutionV1ToV2() async {
    let key = "testKey_\(UUID())"

    // Simulate saving Version 1 data
    let v1State = Version1State(counter: 10, name: "version1")
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    let data = try! encoder.encode(v1State)
    UserDefaults.standard.set(data, forKey: key)

    // Load with Version 2 manager
    let manager = PersistenceManager<Version2State>(persistenceKey: key)
    let loaded = manager.loadState()

    // Should load successfully with defaults for missing properties
    let expected = Version2State(counter: 10, name: "version1", version: 2, config: Config())
    #expect(loaded == expected)
}

/// Tests backward compatibility: loading Version 2 data into Version 3 struct.
/// Version 3 removes properties (including structs), so extra keys in plist are ignored.
@Test @MainActor
func testPersistenceManagerVersionEvolutionV2ToV3() async {
    let key = "testKey_\(UUID())"

    // Simulate saving Version 2 data with struct
    let v2State = Version2State(
        counter: 20, name: "version2", version: 2, config: Config(theme: "dark", enabled: false))
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    let data = try! encoder.encode(v2State)
    UserDefaults.standard.set(data, forKey: key)

    // Load with Version 3 manager
    let manager = PersistenceManager<Version3State>(persistenceKey: key)
    let loaded = manager.loadState()

    // Should load successfully, ignoring extra keys (config struct), version set to current
    let expected = Version3State(version: 3, counter: 20, name: "version2")
    #expect(loaded == expected)
}

// Test events
enum PersistenceTestEvent: AppEvent {
    case persistTrue
    case persistFalse

    var persist: Bool {
        switch self {
            case .persistTrue:
                return true
            case .persistFalse:
                return false
        }
    }

    var isUIEvent: Bool {
        switch self {
            case .persistTrue, .persistFalse:
                return true
        }
    }
}
