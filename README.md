# CalendarBar

A macOS menubar app that shows your Google Calendar events. The menubar title shows your next meeting (for example `Standup · in 12m`), and clicking it opens a list of what's coming up.

Events are fetched by running headless Claude Code (`claude -p`), which uses your Claude account's own Google Calendar connector. There is no Google Cloud project or OAuth setup in this app.

## Features

- **Menubar title:** your next timed event, as `Title · in 12m`, `Title · now`, or `Title · 3:30 PM`.
- **Upcoming list:** events grouped by day (Today, Tomorrow, then weekday and date), with time and location. Click an event to open it in Google Calendar.
- **Earlier today:** meetings that have already ended today, dimmed, above the upcoming list.
- **Team out of office:** events from the "TSM AMER OOO Calendar" in their own light red section below your meetings, with date ranges. They don't affect the menubar title.
- **All calendars:** events come from every calendar you have selected in Google Calendar. Declined events are hidden.
- **Launch at login:** optional toggle in Settings.

## Requirements

- macOS 14 or later
- Swift toolchain (Xcode or the command line tools). Full Xcode is not required.
- [Claude Code](https://claude.com/claude-code) installed and signed in (`claude` on your PATH)
- The Google Calendar connector connected in your claude.ai account. Check with:

```bash
claude mcp list
```

## Build and run

```bash
./build.sh
open build/CalendarBar.app
```

`build.sh` builds a release binary with SwiftPM and wraps it in a menubar-only app bundle at `build/CalendarBar.app` (no Dock icon). The bundle is ad-hoc signed, so it only runs on the Mac that built it. Quit the app from the dropdown.

The first fetch takes around 30 seconds, because it runs a full `claude -p` session.

## Settings

Open the dropdown and choose **Settings…**.

| Setting | Default | Notes |
|---|---|---|
| claude executable | `claude` | Path to the Claude Code CLI if it isn't on your login shell's PATH |
| Model | `sonnet` | Use Sonnet or another model that can use connector tools. Haiku can't see the Google Calendar tools and fails. |
| Days ahead | 7 | How far ahead to fetch. A larger window takes longer and shows more OOO notices. |
| Launch at login | off | Registers the app as a login item |

Events refresh on launch, every 10 minutes, and when you press the refresh button in the dropdown.

For Launch at login, move `CalendarBar.app` somewhere stable such as `~/Applications` first, since a rebuild replaces the copy in `build/`. macOS may ask you to approve the app under System Settings → General → Login Items.

## How it works

1. `ClaudeRunner` runs `claude -p` through a login shell, with only the Google Calendar tool allowed, in JSON output mode.
2. The prompt asks Claude to return a JSON array of events (id, title, start, end, all-day flag, location, link, declined flag, calendar name).
3. `CalendarStore` parses the array and splits events into your meetings, today's finished meetings, and team OOO events (calendar name contains "OOO").
4. `ContentView` renders the dropdown, and `CalendarBarApp` shows the menubar title.

| File | Purpose |
|---|---|
| `Sources/CalendarBar/CalendarBarApp.swift` | App entry point and menubar item |
| `Sources/CalendarBar/CalendarStore.swift` | Fetching, parsing, refresh timers, menubar title |
| `Sources/CalendarBar/ClaudeRunner.swift` | Runs `claude -p` and extracts the JSON reply |
| `Sources/CalendarBar/ContentView.swift` | Dropdown list and sections |
| `Sources/CalendarBar/SettingsView.swift` | Settings window |
| `build.sh` | Builds and bundles the app |

## Cost and limitations

- Each refresh is a full Claude Code run (roughly 15 to 30 seconds and a few cents of usage), which is why it refreshes every 10 minutes rather than more often.
- Claude produces the event list, so results depend on the model following the requested JSON format.
- The app is read-only. It never creates or changes events.
- The OOO section matches on the calendar name containing "OOO". Rename the match in `CalendarStore.swift` (`isOOO`) if your calendar is named differently.

## Troubleshooting

- **Title says `Calendar ⚠︎`:** open the dropdown to see the error message.
- **"I don't have access to Google Calendar tools":** set Model to `sonnet` (not `haiku`), and confirm `claude mcp list` shows Google Calendar as connected.
- **Timed out:** the fetch limit is 180 seconds. Try fewer days ahead.
- **Not running after a restart:** menubar apps don't start by themselves. Turn on Launch at login in Settings.
