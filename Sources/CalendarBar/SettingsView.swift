import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: CalendarStore

    var body: some View {
        Form {
            Section("Claude") {
                TextField("claude executable", text: store.binding(\.claudePath), prompt: Text("claude"))
                TextField("Model", text: store.binding(\.claudeModel), prompt: Text("sonnet"))
                Stepper("Days ahead: \(store.daysAhead)", value: store.binding(\.daysAhead), in: 1...30)
            }
            Text("Events are fetched by running `claude -p`, which uses your Claude account's own Google Calendar connector. Make sure it's connected in claude.ai. Refreshes every 10 minutes.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Save & Refresh") { Task { await store.refresh() } }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
    }
}

extension CalendarStore {
    func binding<T>(_ keyPath: ReferenceWritableKeyPath<CalendarStore, T>) -> Binding<T> {
        Binding(get: { self[keyPath: keyPath] }, set: { self[keyPath: keyPath] = $0; self.objectWillChange.send() })
    }
}
