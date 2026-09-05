# MenuBarCalendar

MenuBarCalendar is a lightweight macOS menu bar app that puts a full month calendar and your upcoming Calendar.app events one click away. It reads your existing Apple Calendar accounts read-only, highlights today and weekends, shows a colour dot per calendar for each day with events, and lists upcoming events with automatic scrolling to the current or next entry. Tapping an event opens it directly in Apple Calendar.

![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-native-green)

---

## Screenshots

![screenshot](./screenshot.jpg)

---

## Features

- 📅 **Month calendar grid** — week starts on Monday, with ISO week numbers
- 🎯 **Today highlighted** with accent colour; selected day with outline
- 🔴 **Weekend dates** in red
- 🟢 **Event dots** per calendar colour (up to 3 per day)
- 📋 **Upcoming events list** — scrolls to current or next event automatically
- 🗓 **Opens Apple Calendar** on event tap
- ⚙️ **Settings** — select which calendars to show, toggle launch at login
- 🌍 **Localised** — English and German (follows system language)
- 🌙 **Midnight refresh** — icon and selected date always show today
- 🚀 **Launch at Login** support via `SMAppService`
- 🔒 No dock icon (`LSUIElement` / `NSApp.setActivationPolicy(.accessory)`)

---

## Requirements

| | |
|---|---|
| macOS | 14.0 Sonoma or later |
| Architecture | Apple Silicon only |
| Xcode | 15 or later |
| Swift | 5.9 or later |

---

## Installation

### Build from source

1. Clone the repository:
   ```bash
   git clone https://github.com/dirkclemens/MenuBarCalendar.git
   cd MenuBarCalendar
   ```
2. Open `MenuBarCalendar.xcodeproj` in Xcode.
3. Select the `MenuBarCalendar` scheme and your Mac as the target.
4. Build and run (`⌘R`).

### Calendar permission

On first launch macOS will ask for **Calendar access**. You can also grant it manually in:

> System Settings → Privacy & Security → Calendars → MenuBarCalendar ✓

### Prebuilt DMG

A ready-to-run build is available as `MenuBarCalendar-1.0.dmg` (ad-hoc signed, Apple Silicon only). Since it isn't notarized by Apple, macOS blocks it on first launch. Remove the quarantine flag before opening:

```bash
xattr -dr com.apple.quarantine /Applications/MenuBarCalendar.app
```

Alternatively, right-click the app in Finder and choose "Open".

---

## Project Structure

```
MenuBarCalendar/
├── AppDelegate.swift                    # App lifecycle, midnight icon timer, launch at login
├── CalendarManager.swift                # EventKit access, event fetching, calendar state
├── MenuBarCalendar.swift                # @main App entry point, MenuBarExtra
├── Views/
│   ├── CalendarView.swift               # Root view
│   ├── CalendarNavigationView.swift     # Month header + prev/today/next buttons
│   ├── CalendarGridView.swift           # Week grid with day cells
│   ├── DayCellView.swift                # Individual day cell
│   ├── WeekNumberView.swift             # ISO week number column
│   ├── EventDotsView.swift              # Coloured event dot indicators
│   ├── EventsListView.swift             # Scrollable upcoming events list
│   ├── DaySectionView.swift             # Day group header + event rows
│   ├── EventRowView.swift               # Single event row with time and video indicator
│   ├── NoAccessView.swift               # Shown when calendar access is denied
│   ├── EmptyEventsView.swift            # Shown when no upcoming events
│   └── CalendarToolBarView.swift        # Bottom bar (Settings / Quit)
├── Settings/
│   ├── SettingsView.swift               # Settings form
│   ├── CalendarsListView.swift          # Grouped calendar list
│   ├── CalendarSelectionView.swift      # Single calendar toggle row
│   └── SettingsRowView.swift            # Generic settings row with icon + chevron
├── en.lproj/Localizable.strings
└── de.lproj/Localizable.strings
```

## Localisation

The app ships with **English** and **German**. To add another language:

1. Add the language in Xcode → Project → Info → Localizations.
2. Duplicate `en.lproj/Localizable.strings` into the new `xx.lproj/` folder.
3. Translate the values.

## Privacy

MenuBarCalendar requests **read-only** access to your calendars (`NSCalendarsUsageDescription`). No data leaves your device.

## Credits

Inspired by [itsybitsycal](https://github.com/harryfliu/itsybitsycal) by [@harryfliu](https://github.com/harryfliu).

---

## License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0) — see [LICENSE](LICENSE) for details. Free for noncommercial use; commercial use requires a separate license from the author.
