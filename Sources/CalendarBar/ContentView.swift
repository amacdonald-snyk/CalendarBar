import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: CalendarStore
    @Environment(\.openSettings) private var openSettings

    private var days: [(day: Date, events: [CalendarEvent])] {
        let cal = Calendar.current
        let visible = store.events.filter { $0.end > store.now && !$0.isDeclined }
        let grouped = Dictionary(grouping: visible) { cal.startOfDay(for: max($0.start, cal.startOfDay(for: store.now))) }
        return grouped.keys.sorted().map { ($0, grouped[$0]!) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if let error = store.errorMessage {
                Text(error)
                    .font(.callout).foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(12)
                Divider()
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if days.isEmpty && !store.isLoading && store.errorMessage == nil {
                        Text("Nothing scheduled.").foregroundStyle(.secondary).padding(.top, 8)
                    }
                    ForEach(days, id: \.day) { section in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dayLabel(section.day))
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            ForEach(section.events) { EventRow(event: $0, now: store.now) }
                        }
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 420)
            Divider()
            footer
        }
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            Text("Upcoming").font(.headline)
            Spacer()
            if store.isLoading { ProgressView().controlSize(.small) }
            Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless).disabled(store.isLoading).help("Refresh")
        }
        .padding(12)
    }

    private var footer: some View {
        HStack {
            if let updated = store.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Settings…") { NSApp.activate(ignoringOtherApps: true); openSettings() }
                .buttonStyle(.borderless)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless).keyboardShortcut("q")
        }
        .padding(10)
    }

    private func dayLabel(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInTomorrow(d) { return "Tomorrow" }
        return d.formatted(.dateTime.weekday(.wide).month().day())
    }
}

struct EventRow: View {
    let event: CalendarEvent
    let now: Date

    var body: some View {
        let live = !event.isAllDay && event.start <= now && event.end > now
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(live ? Color.green : Color.accentColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).lineLimit(2)
                Text(timeText).font(.caption).foregroundStyle(.secondary)
                if let loc = event.location, !loc.isEmpty {
                    Text(loc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { if let link = event.link { NSWorkspace.shared.open(link) } }
    }

    private var timeText: String {
        if event.isAllDay { return "All day" }
        let t = Date.FormatStyle(date: .omitted, time: .shortened)
        return "\(event.start.formatted(t)) – \(event.end.formatted(t))"
    }
}
