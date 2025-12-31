import SwiftUI
import WaveState

public struct EventRow: View {
    let entry: EventEntry

    public var body: some View {
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
    }
}