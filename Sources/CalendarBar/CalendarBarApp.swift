import SwiftUI

@main
struct CalendarBarApp: App {
    @StateObject private var store = CalendarStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(store)
        } label: {
            Image(systemName: "calendar")
            Text(store.menuBarTitle)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(store)
        }
    }
}
