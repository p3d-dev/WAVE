import SwiftUI
import WaveState
import WaveViews

#if os(macOS)
    import AppKit
#endif

#if os(macOS)
    public class AppDelegate: NSObject, NSApplicationDelegate {
        public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
        {
            return true
        }
    }
#endif

/// The main application structure for the WAVE demo app.
/// Manages state, persistence, and effects for the cross-platform app.
@MainActor
public struct WaveDemoApp: App {
    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    public init() {}

    public var body: some Scene {
        WindowGroup {
            AppContentView()
        }
    }
}

struct AppContentView: View {
    @State var stateManager: AppUIStateManager?

    /// Initializes and configures the state manager with reducers, effects, and default state.
    /// This function contains all the setup logic previously in onAppear for better organization.
    func initializeStateManager() async -> AppUIStateManager {
        let recorderFilter: @Sendable (any AppEvent) async -> Bool = { event in
            await EventRecorder.shared.dispatchFilter(event: event)
        }

        let stateManager = await AppUIStateManager(
            defaultState: { @Sendable in
                return AppStateAlias(t: ExampleTransient(), p: ExamplePersistent())
            },
            dispatchFilter: recorderFilter
        )

        // PITFALL: Missing event reducer registration - Ensure all reducers are added here.
        // Without registered reducers, events won't update the state.
        // Replace 'ExampleReducer()' with your feature's reducer instance
        // Use AnyReducer<AppStateAlias> to wrap your reducer for type safety
        await stateManager.addReducer(
            AnyReducer<AppStateAlias>(ExampleReducer()))

        await stateManager.addReducer(
            AnyReducer<AppStateAlias>(
                EventLoggingAppReducer(keyPath: \.t.eventLogging)))

        // PITFALL: Forgetting to set up effects processor can lead to missing side effects
        // (e.g., analytics, network calls, persistence). Always call setEffects even if empty.
        let effectsProcessor = EffectsProcessor(stateManager: stateManager)

        await stateManager.setEffects { [effectsProcessor] event, state in
            await effectsProcessor.process(event: event, state: state.p)
        }

        return stateManager
    }

    var body: some View {
        Group {
            if let stateManager {
                MainLayoutView(stateManager: stateManager)
                    // This provides a closure that views can use to dispatch events to the state manager
                    // Views access this via @Environment(\.appDispatch) and call it to trigger state changes
                    .environment(
                        \.appDispatch,
                        { stateManager.dispatch($0) }
                    )
                    // PITFALL: Missing state object creation - Views must use @Environment(\.objectFactory) to create StateObjects.
                    // Never instantiate StateObjects directly; always use the factory for proper listener registration.
                    // This factory creates StateObjects and automatically sets up state forwarding
                    // Views access this via @Environment(\.objectFactory) to get properly initialized StateObjects
                    .environment(
                        \.objectFactory,
                        AppStateObjectFactory(stateManager: stateManager)
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
