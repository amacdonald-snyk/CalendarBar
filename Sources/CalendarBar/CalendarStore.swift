import Foundation
import SwiftUI

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let link: URL?

    var isDeclined: Bool = false
}

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var now = Date()

    @AppStorage("claudePath") var claudePath = "claude"
    @AppStorage("claudeModel") var claudeModel = "sonnet"
    @AppStorage("daysAhead") var daysAhead = 7

    private var tick: Timer?
    private var refreshTimer: Timer?

    init() {
        tick = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    // MARK: - Menubar title

    var upcoming: [CalendarEvent] {
        events.filter { !$0.isAllDay && $0.end > now && !$0.isDeclined }
    }

    var menuBarTitle: String {
        if errorMessage != nil && events.isEmpty { return "Calendar ⚠︎" }
        guard let next = upcoming.first else { return events.isEmpty ? "No events" : "Done for today" }
        let name = next.title.count > 24 ? next.title.prefix(23) + "…" : next.title
        if next.start <= now { return "\(name) · now" }
        let mins = Int(next.start.timeIntervalSince(now) / 60)
        if mins < 60 { return "\(name) · in \(max(mins, 1))m" }
        return "\(name) · \(next.start.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Fetching

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: Date())
            let end = cal.date(byAdding: .day, value: max(daysAhead, 1), to: startOfDay)!
            let text = try await ClaudeRunner.fetchEventsJSON(
                executable: claudePath.isEmpty ? "claude" : claudePath,
                model: claudeModel, from: startOfDay, to: end)
            events = try Self.parseEvents(text)
            errorMessage = nil
            lastUpdated = Date()
            now = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Parsing

    private static func parseEvents(_ text: String) throws -> [CalendarEvent] {
        guard let data = text.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ClaudeError.badOutput(String(text.prefix(300)))
        }
        var seen = Set<String>()
        return raw.compactMap { e -> CalendarEvent? in
            guard let id = e["id"] as? String,
                  let start = parseDate(e["start"] as? String),
                  let end = parseDate(e["end"] as? String) else { return nil }
            guard seen.insert("\(id)|\(start.timeIntervalSince1970)").inserted else { return nil }
            var ev = CalendarEvent(
                id: id,
                title: (e["title"] as? String) ?? "(No title)",
                start: start, end: end,
                isAllDay: e["allDay"] as? Bool ?? false,
                location: e["location"] as? String,
                link: (e["link"] as? String).flatMap(URL.init(string:))
            )
            ev.isDeclined = e["declined"] as? Bool ?? false
            return ev
        }
        .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    private static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: s)
    }
}
