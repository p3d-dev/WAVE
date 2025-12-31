import SwiftUI
import WaveState
import WaveViews

/// StateObject for displaying logged events.
public final class EventStateObject: ObservableObject {
    @Published public var events: [EventEntry]

    public init(events: [EventEntry] = []) {
        self.events = events
        print("EventStateObject created")
    }
    deinit {
        print("EventStateObject deinit")
    }
}

/// View for displaying the list of logged events.
public struct EventView: View {
    @StateObject var stateObject: EventStateObject
    @Environment(\.appDispatch) private var appDispatch: AppDispatch

    public init(stateObject: EventStateObject) {
        self._stateObject = StateObject(wrappedValue: stateObject)
    }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Event Log (\(stateObject.events.count))")
                    .font(.headline)
                Spacer()
                Button(action: {
                    appDispatch(EventLoggingEvent.replay)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
            }
            .padding(.bottom, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                         ForEach(stateObject.events) { entry in
                             EventRow(entry: entry)
                                 .id(entry.id)
                         }
                    }
                    .padding(.horizontal)
                }
                .onReceive(stateObject.$events) { events in
                    if let last = events.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .border(Color.gray.opacity(0.2))
    }
}