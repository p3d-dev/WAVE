import SwiftUI
import WaveState
import WaveViews

/// StateObject for displaying logged events.
public final class EventStateObject: ObservableObject {
    @Published public var events: [EventLoggingEntry]

    public init(events: [EventLoggingEntry] = []) {
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
                            HStack(alignment: .top) {
                                VStack(alignment: .leading) {
                                    let eventName = String(
                                        entry.typeName.split(separator: ".").last ?? "")
                                    Text("\(eventName): \(entry.description)")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(entry.isUIEvent ? "UI" : "BG")
                                        .font(.caption)
                                        .padding(2)
                                        .background(
                                            entry.isUIEvent
                                                ? Color.green.opacity(0.2) : Color.gray.opacity(0.2)
                                        )
                                        .cornerRadius(4)
                                    if entry.persist {
                                        Text("Persist")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding(6)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(4)
                            .id(entry.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: stateObject.events) {
                    if let last = stateObject.events.last {
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
