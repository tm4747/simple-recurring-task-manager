# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An iOS app (SwiftUI + SwiftData) implementing recurring/one-time task reminders that actively alarm and re-notify until dealt with — not a passive checklist. Full product spec, data model, and the phase-by-phase build plan this app was built against live in `docs/PRD.md`; read it before making product-behavior decisions, since it's the source of truth for intended behavior (recurrence rules, Do Now button semantics, mileage prompting schedule, etc.).

Two sibling projects at `../SimpleTimer` and `../SimpleBoxingTimer` are the source of several ported subsystems (theme system, voice-to-text, header bar, Past-Done-style history grouping) — when extending those subsystems, check the sibling's implementation for the established convention rather than inventing a new one.

## Build & test commands

The system Xcode Command Line Tools are active by default (`xcode-select`), not full Xcode, so `xcodebuild` needs `DEVELOPER_DIR` pointed at the real Xcode explicitly:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

**Plain build** (app + widget extension, compile-only — use this to self-verify most changes):
```bash
xcodebuild -project SimpleRecurringTaskManager.xcodeproj -scheme SimpleRecurringTaskManager \
  -destination "generic/platform=iOS Simulator" build
```

**Run in Simulator**: build with a concrete simulator destination (`xcrun simctl list devices` for available UDIDs/names), then `xcrun simctl install`/`launch`. `-destination "platform=iOS Simulator,name=iPhone 17 Pro"` also works in place of a UDID.

**Tests** — two targets sharing one scheme: `SimpleRecurringTaskManagerTests` (Swift Testing, unit) and `SimpleRecurringTaskManagerUITests` (XCTest, end-to-end). A full run takes several minutes; prefer targeting just what changed:
```bash
# Compile the test targets without running anything
xcodebuild -project SimpleRecurringTaskManager.xcodeproj -scheme SimpleRecurringTaskManager \
  -destination "id=<simulator-udid>" build-for-testing

# Run one class or one method
xcodebuild test-without-building -xctestrun <path-to-.xctestrun-from-build-for-testing> \
  -destination "id=<simulator-udid>" \
  -only-testing:SimpleRecurringTaskManagerTests/RecurrenceEngineTests
  -only-testing:SimpleRecurringTaskManagerUITests/TaskCreationUITests/testCreatingATaskShowsItInTheList

# Full suite
xcodebuild test -project SimpleRecurringTaskManager.xcodeproj -scheme SimpleRecurringTaskManager \
  -destination "id=<simulator-udid>"
```

UI tests launch with `app.launchArguments = ["UI-TESTING"]`, which routes `SharedModelContainer` to an in-memory store (`SharedModelContainer.isUITesting`) instead of the real App Group container — every UI test run starts from the same empty, deterministic state.

## Architecture

### Four targets, one hand-edited project file

`SimpleRecurringTaskManager` (app), `SimpleRecurringTaskManagerWidgetExtension`, `SimpleRecurringTaskManagerTests`, `SimpleRecurringTaskManagerUITests` — all four targets and the shared scheme (`.xcodeproj/xcshareddata/xcschemes/`) were added by hand-editing `project.pbxproj` rather than through Xcode's UI (this project uses Xcode's file-system-synchronized groups, i.e. `PBXFileSystemSynchronizedRootGroup` — dropping a `.swift` file into a target's folder is enough for it to be compiled into that target, no pbxproj edit needed for ordinary source files). If you ever need to add a *target* by hand again, `PBXFileSystemSynchronizedBuildFileExceptionSet` is how a specific file (e.g. `Info.plist`) gets excluded from a synchronized group's automatic membership — needed anywhere `INFOPLIST_FILE` points at a file that also lives inside a synchronized folder, or it'll collide with the generated Info.plist during Copy Bundle Resources.

### Widget ↔ app data sharing

The widget extension is a separate process and can't share Swift types across a module boundary via the synchronized-group mechanism, so the handful of `@Model` files it needs (`TaskItem`, `Category`, `Car`, `MileageEntry`, `TaskDoneItem`, `SnoozeOption`, `AppSettings`, plus `RecurrenceType`/`TaskStatus`/`AppTheme`) are **duplicated verbatim** into `SimpleRecurringTaskManagerWidget/Shared/` rather than referenced from one location. Same for `SharedModelContainer.swift` itself. If you change a model's schema, change both copies or the two processes will disagree about the store's shape. Both processes point at the same SQLite file via the App Group container (`group.Tom.SimpleRecurringTaskManager`, `SharedModelContainer.make()`), not the app's own sandbox.

### Data layer

All `@Model` types use a UUID `id` (not `persistentModelID`) and optional-only relationships (no unique constraints) — a deliberate CloudKit-compatibility choice even though sync isn't implemented yet. Relationships lean on SwiftData's inverse-relationship delete rules rather than manual cleanup: `Category`/`Car` deletion nullifies (tasks become uncategorized/car-less), `TaskItem` deletion cascades to its `TaskDoneItem`s.

**Known SwiftData gotcha**: `task.doneItems` (the inverse side of a relationship) is not guaranteed to reflect a same-context `modelContext.insert()` synchronously at read time. Code that just inserted a `TaskDoneItem` and needs to compute something from "the most recent completion" in the same call must pass that completion in explicitly rather than re-deriving it by reading the relationship back — see `RecurrenceEngine.recalculatedNextDue(for:justCompletedAt:)` and `MileageEngine.recalculatedNextDue(for:car:justCompleted:)`. Getting this wrong previously caused a real bug: the alarm re-firing immediately after a task was marked Done, because the recalculation silently fell back to a stale past date.

### The "engine" pattern

Pure, stateless calculation logic lives in standalone enums with static functions, deliberately kept separate from the views that call them so they're unit-testable without SwiftUI or a real `ModelContext`:
- `RecurrenceEngine` — next_due for calendar-based recurrence (daily/weekly/monthly/nth-weekday/specific-weekdays/etc).
- `MileageEngine` — mileage estimation, the by-mileage next_due calculation (whichever of the mileage/time trigger comes first), and the per-car mileage-prompt schedule.
- `StreakCalculator` — consecutive on-time completions.

`TaskItem.isDueForDecision` (in `TaskItem.swift`) is the single source of truth for "does this task need a decision right now" — it switches on `status` (`.snoozed` cares about `snoozeUntil`, `.doingNow`/`.checkingNow` care about `doingNowDeadline`, everything else cares about `nextDue`). Both `ContentView`'s foreground-alarm trigger and `DoNowContainerView`'s routing filter on this one property; don't duplicate its logic elsewhere. Note `isOverdue` is a *display-only* flag (drives red highlighting per the PRD, persists until Done) and must never factor into due-ness — it gets set unconditionally by snooze/defer, so folding it into "is due" would make snoozing/deferring immediately re-trigger the alarm.

### Do Now flow

`ContentView` polls `isDueForDecision` (on scene-phase changes and a 15s timer while foregrounded) and full-screen-covers the tab bar with `DoNowContainerView` whenever any task qualifies. The container shows `DoNowView` directly for one due task, or `DoNowQueueView`'s card list for several; picking a card swaps in that task's `DoNowView`. There's no manual "return to queue" — finishing a task's action always changes something that makes it stop being due, so the queue reappears (or the whole cover dismisses) automatically on the next render.

### Theming

`Theme` (colors/typography/metrics) is resolved once in `ContentView` from `AppSettings.selectedTheme` and injected via `@Environment(\.theme)`; every other view reads it from there rather than resolving it independently. Views never hardcode a color/font — see `Theming/ThemeTokens.swift` for the three themes (Light/Dark/Retro) and `Theming/ThemeModifiers.swift` / `ThemedButtonStyle.swift` for the drop-in replacements for system styling (`.themedScreenBackground()`, `PrimaryButtonStyle()`, etc.) that every screen uses instead of raw SwiftUI modifiers.

### Notifications & alarms

`NotificationScheduler` schedules a due-time local notification plus 5 staggered 5-minute follow-ups per task (cancelled and rescheduled together on every create/edit/complete/snooze/defer) — no critical-alerts entitlement, `.timeSensitive` interruption level instead. `AlarmPlayer` is the separate foreground-only in-app sound loop, stopped the instant the user interacts with the Do Now screen.

### Voice-to-text

`SpeechInputManager` + `SpokenLabelField` (ported from `../SimpleTimer`) is the mic-icon-with-2s-silence-auto-commit text input used everywhere text is entered (task title, category/car name, done note). Reuse `SpokenLabelField` for any new text input rather than a plain `TextField`, per the PRD's "voice-to-text on all non-numeric inputs" requirement.

## UI testing notes

- Tapping a `List` row that's a custom multi-line `Button` label can be unreliable via XCUITest's synthetic `.tap()` in this project — tapping the row's inner `StaticText` (e.g. the title) resolves more reliably than tapping the outer `Button` element or a raw coordinate tap. See `TaskCreationUITests` for the established pattern.
- `Menu(primaryAction:)`-based buttons (the "tap = default action, hold = reveal options" pattern used for Snooze/Do It Tomorrow/Do It Weekend) don't reliably resolve a synthetic `.tap()` to the primary-action gesture. Tests that need to get past the Do Now screen use the plain `Button`-based "Do It This Evening" action instead.
