import Foundation

/// Protocol for persistent state that includes a version field for schema evolution.
/// Conforming types must implement `init(from:)` for backward compatibility when adding new keys.
public protocol PersistentState: Codable, Equatable, Sendable {
    /// The version of the state schema. Increment when adding/removing properties.
    var version: Int { get }
}

/// Manages debounced persistence to avoid excessive UserDefaults writes
public final class PersistenceManager<State: PersistentState>: PersistenceManagerProtocol {

    private let persistenceKey: String
    @MainActor private var lastSavedState: State?
    @MainActor private var pendingState: State?
    @MainActor private var saveTask: Task<Void, Never>?

    /// Initializes the persistence manager with a custom key
    /// - Parameter persistenceKey: The UserDefaults key for storing the state
    public init(persistenceKey: String) {
        self.persistenceKey = persistenceKey
    }

    /// Saves state with debouncing to prevent excessive writes
    @MainActor public func saveStateIfNeeded(_ state: State, for event: any AppEvent) async {
        // Cancel any pending save
        saveTask?.cancel()

        let shouldPersist = event.persist
        guard shouldPersist else { return }
        if lastSavedState == state || pendingState == state {
            return
        }

        let stateToPersist = state
        pendingState = stateToPersist

        // Debounce saves by 0.5 seconds to batch rapid changes
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
            guard !Task.isCancelled else { return }

            do {
                let data = try encode(stateToPersist)
                UserDefaults.standard.set(data, forKey: persistenceKey)
                await MainActor.run {
                    self.lastSavedState = stateToPersist
                    if self.pendingState == stateToPersist {
                        self.pendingState = nil
                    }
                }

            }
            catch {
                await MainActor.run {
                    if self.pendingState == stateToPersist {
                        self.pendingState = nil
                    }
                }

            }
        }

    }

    /// Loads persisted state from UserDefaults
    /// - Returns: The persisted state if available, nil otherwise
    public func loadState() -> State? {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return nil }

        do {
            let state = try decodePropertyList(from: data)
            Task {
                await MainActor.run {
                    self.lastSavedState = state
                    self.pendingState = nil
                }
            }

            return state
        }
        catch {

            return nil
        }
    }

    /// Immediately saves state to UserDefaults without debouncing
    /// Useful for app backgrounding or other scenarios requiring immediate persistence
    /// - Parameter state: The state to save
    @MainActor public func saveStateImmediately(_ state: State) {
        if lastSavedState == state || pendingState == state {
            return
        }
        do {
            let data = try encode(state)
            UserDefaults.standard.set(data, forKey: persistenceKey)
            lastSavedState = state
            pendingState = nil

        }
        catch {

        }
    }

    /// Waits for any pending debounced save to finish (primarily for testing).
    @MainActor public func flushPendingSaves() async {
        let task = saveTask
        await task?.value
    }

    private func encode(_ state: State) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(state)
    }

    private func decodePropertyList(from data: Data) throws -> State {
        let decoder = PropertyListDecoder()
        return try decoder.decode(State.self, from: data)
    }
}
