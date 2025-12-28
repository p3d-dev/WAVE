import SwiftUI
import WaveState
import WaveViews

/// This demonstrates how to compose different features in a single view.
/// Replace 'MainLayoutView' with your app's main layout component.
/// Shows pattern for using objectFactory to create StateObjects for features.
struct MainLayoutView: View {
    private let stateManager: AppUIStateManager

    @Environment(\.objectFactory) private var objectFactory

    init(stateManager: AppUIStateManager) {
        self.stateManager = stateManager
    }

    var body: some View {
        // PITFALL: Missing listener registrations - Always use objectFactory.makeStateObject() to create StateObjects.
        // This ensures the StateObject is registered as a listener and stays in sync with app state.
        // This pattern allows dependency injection and proper lifecycle management
        if let objectFactory, let es: ExampleStateObject = objectFactory.makeStateObject() {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Pass the StateObject created by the factory
                    ExampleView(stateObject: es)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack {
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.05))
            }
            .frame(minWidth: 800, minHeight: 600)
            .clipped()
        }
    }
}
