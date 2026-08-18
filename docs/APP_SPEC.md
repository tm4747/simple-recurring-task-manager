# Simple Recurring Task Manager — Current-State Feature Specification

This document describes what the app actually does today, verified directly against
the current source code (not the original plan). It is written to be platform-agnostic
so it can drive a rebuild on another platform (e.g. Android) — implementation details
specific to iOS/SwiftUI are called out explicitly as "iOS-specific" so a porting effort
knows what needs an equivalent vs. what can be dropped.

This is a **different document from `docs/PRD.md`**: the PRD was the original plan
written before the app existed, and it's now stale — many things below were added,
changed, or removed during development and are not reflected there. This document
supersedes it as the source of truth for current behavior.

---

## 1. App Overview

A recurring task/reminder manager built around one core idea: recurring tasks (chores,
maintenance, checks) are tracked with a next-due date, and when that date arrives the
app takes over the screen and sounds an alarm until the user makes a decision about it —
not just a passive notification the user can ignore. The four buckets of task type:

- **Simple recurring tasks** — repeat on a calendar cadence (daily, weekly, monthly,
  etc.)
- **"Check first" tasks** — a variant where the user first checks whether the task is
  even needed, before deciding to do it or not.
- **Car maintenance tasks** — recur based on estimated mileage and/or elapsed time,
  tied to a specific car whose mileage is tracked/estimated over time.
- **One-time tasks** — fire once and never recur.

The app has three tabs: **Tasks** (the list + create/edit), **Past Done** (completion
history), **Settings**.

---

## 2. Data Model

### TaskItem
The central entity.

| Field | Type | Notes |
|---|---|---|
| id | UUID | stable identity |
| title | text | |
| category | ref → Category, optional | |
| car | ref → Car, optional | only set for car-maintenance tasks |
| isCheckFirst | bool | enables the "check first" flow |
| recurrenceType | enum | see §2a |
| recurrenceWeekNumber | int 1–5, optional | only for `nthWeekdayOfMonth`; 5 = "last" |
| recurrenceWeekday | int 1–7, optional | only for `nthWeekdayOfMonth`; 1 = Sunday |
| recurrenceWeekdays | int[] 1–7, optional | only for `specificWeekdays` |
| firstOccurrence | datetime | the anchor date used when there's no completion history yet |
| nextDue | datetime, optional | the currently-computed due date/time; null = not currently scheduled |
| timeTakesToDo | duration, optional | if set, "I'll Do It Now" starts a silent countdown of this length instead of asking |
| timeTakesToCheck | duration, optional | same, for check-first's "I'll Check It Now"; required whenever isCheckFirst is true |
| mileageTrigger | int, optional | car-maintenance only: miles until due |
| timeTriggerMonths | int, optional | car-maintenance only: months until due |
| isOverdue | bool | **display-only** flag — drives red highlighting in the list. Does NOT participate in "is this due for a decision" logic (see §5.1's note on why) |
| status | enum | `pending`, `active`, `snoozed`, `deferred`, `doingNow`, `checkingNow` |
| snoozeUntil | datetime, optional | set when status = snoozed |
| doingNowDeadline | datetime, optional | the countdown end for `doingNow`/`checkingNow` |
| createdAt / updatedAt | datetime | |

Has a one-to-many relationship to **TaskDoneItem** (completion history).

### TaskDoneItem
One row per completion (or per check-first "checked, not needed" outcome).

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| task | ref → TaskItem | |
| completedAt | datetime | |
| wasDone | bool | true = actually performed; false = check-first task was checked and found not to need doing |
| note | text, optional | user's optional note at completion time |
| mileageAtCompletion | int, optional | car-maintenance only |
| wasOnTime | bool | snapshot of "was this NOT overdue" at the moment of completion — needed because the live isOverdue flag gets reset right after completion, so it can't be read back later. Drives streak calculation. |

### Category
| Field | Notes |
|---|---|
| id, name | |
| isSystem | true only for the built-in "Car Maintenance" category — not user-deletable or renamable |
| createdAt | |

One system category, **"Car Maintenance"**, is seeded automatically on first launch and
can never be deleted or renamed. Any task whose category is set to it becomes a
car-maintenance task (see §4.2).

### Car
| Field | Notes |
|---|---|
| id, name | |
| initialMileage | optional, set at car creation |
| monthlyMileageEstimate | optional, user's initial guess; superseded once 2+ real mileage entries exist |
| createdAt / updatedAt | |

Has a one-to-many relationship to **MileageEntry** and to the TaskItems assigned to it.

### MileageEntry
| Field | Notes |
|---|---|
| id, car | |
| mileage | int |
| recordedAt | datetime |
| isUserEntered | bool — false for system-interpolated backfill entries (§5.2) |

### SnoozeOption
Four user-configurable durations offered on the Snooze button's hold-menu.
`label`, `durationSeconds`, `sortOrder`.

### AppSettings
Single row, created on first launch, edited in place forever after.

| Field | Notes |
|---|---|
| defaultSnoozeSeconds | what plain-tap Snooze uses |
| eveningTime | time-of-day only (date part ignored) — "Do It This Evening" target |
| weekendDefaultTime | time-of-day AND weekday (Sat or Sun) — "Do It This/Next Weekend" target |
| selectedTheme | "light" / "dark" / "retro" |
| alarmSound | which bundled sound to loop/notify with |
| alarmDurationSeconds | how long the foreground alarm loops before auto-stopping |
| widgetEnabled | toggles whether the home-screen widget shows real data or a placeholder (iOS-specific concern, see §9) |

### 2a. RecurrenceType (enum)
`oneTime`, `daily`, `weekly`, `biweekly`, `monthly`, `biannually` (every 6 months),
`annually`, `firstOfMonth`, `nthWeekdayOfMonth` (e.g. "2nd Tuesday", "Last Friday"),
`specificWeekdays` (multi-select, e.g. Mon/Wed/Fri), `byMileage` (car-maintenance only —
not user-selectable directly; it's implied by choosing the Car Maintenance category).

### 2b. TaskStatus (enum)
`pending` (normal, waiting for nextDue), `active` (unused distinct state currently,
reserved), `snoozed`, `deferred` (user picked a "do it later" option), `doingNow`
(mid-countdown after "I'll Do It Now"), `checkingNow` (mid-countdown after "I'll Check
It Now").

---

## 3. Navigation Structure

Three-tab bottom navigation:
1. **Tasks** — list view, entry point for creating tasks/categories
2. **Past Done** — completion history
3. **Settings**

A full-screen "Do Now" flow (§5) can cover the whole app at any time, taking priority
over everything else, whenever any task becomes due. A full-screen mileage-prompt flow
(§6.4) takes over when a car's mileage is due to be asked for, but only if nothing is
currently due for a Do Now decision (Do Now always wins if both apply).

Task creation/edit and category creation/management are presented as modal sheets over
the Tasks list.

---

## 4. Screens & Behavior

### 4.1 Tasks List (Tasks tab)

- Header: title "Tasks" with a "+" (circle-plus icon) button beside the title that
  opens the New Task form.
- Below the header: a category filter row —
  - A dropdown ("All" + every user category) that filters the list to just that
    category.
  - A "New Category" button (folder+plus icon) that opens category creation.
- The list itself, grouped into sections:
  - **"Overdue"** section (if any) — every task whose `isOverdue` flag is true, sorted
    by nextDue ascending. Always appears first regardless of category grouping.
  - One section per category (alphabetically sorted by category name; tasks with no
    category group under "Uncategorized"), each containing that category's non-overdue
    tasks sorted by nextDue ascending.
- Each row shows: title (in the destructive/red color if overdue), a subtitle line
  (car name if car-maintenance, then next-due date/time, joined by " • "; "No due date"
  if neither applies), and — if the task's current on-time streak is 2 or more — a line
  reading "N in a row on time".
- Overdue rows get a tinted (red, low-opacity) row background in addition to the red
  text.
- Tapping a row opens that task in the edit form.
- Swipe-left on a row reveals a red **Delete** action (confirms via a "Delete This
  Task? This can't be undone." dialog before actually deleting; deletion also cancels
  that task's pending notifications).
- Empty state ("No Tasks Yet") shown when the filtered list is empty.
- The app badge count (iOS home-screen icon badge) is kept in sync with the count of
  tasks that are currently overdue or past their nextDue.

### 4.2 New/Edit Task Form

One form serves both creation and editing.

**Title** — required text field with voice-to-text mic button (§8).

**Category** — picker (Uncategorized + all user categories), a "New Category" inline
button that opens category creation without leaving the form, and a **"Check First"**
toggle. Turning on Check First later adds an "I'll Check It Now" option to that task's
Do Now screen (§5.2) and requires a "time to check" duration below.

**Recurrence** (hidden and replaced by Car Maintenance fields when the selected
category is the system "Car Maintenance" category):
- "Repeats" picker: One Time, Daily, Weekly, Biweekly, Monthly, Every 6 Months,
  Annually, 1st of Month, Nth Weekday of Month, Specific Weekdays.
- If "Nth Weekday of Month": two extra pickers — which occurrence (1st/2nd/3rd/4th/
  Last) and which weekday.
- If "Specific Weekdays": a 7-button multi-select row (Sun–Sat), at least one required.

**Car Maintenance** (shown instead of Recurrence, only reachable by selecting the
system "Car Maintenance" category):
- Car picker (+ inline "New Car" button). If no cars exist yet when this category is
  selected, the New Car form opens automatically.
- Mileage Trigger (numeric, e.g. "5000" = due every 5000 miles) — optional.
- Time Trigger in Months (numeric, e.g. "24") — optional.
- At least one of the two triggers is required to save. If both are set, whichever is
  reached first wins (the earlier computed date is used).
- Selecting this category forces the task's underlying recurrence type to `byMileage`.

**Schedule** (creation only — editing shows a plain "First Occurrence" date/time
picker instead, since an existing task's schedule is already anchored to real
completion history):

A 3-way segmented control, **"Schedule Based On"**, controls how the brand-new task's
initial due date is seeded:
- **"Next Occurs"** (default) — user directly picks the exact date/time the task is
  first due. No completion history is created.
- **"Last Done"** — user picks a date representing when they last actually did this
  task; the next-due date is then computed by stepping the recurrence cadence forward
  from that date, exactly as if they'd just marked it Done on that date. This silently
  seeds one backdated TaskDoneItem.
- **"Start Now"** — shorthand for "I'm doing this for the first time right now";
  behaves like "Last Done" pinned to the current moment (no date picker shown). A task
  created this way is NOT immediately due, unlike "Next Occurs" defaulting to "now."

A footer caption under this control explains whichever option is currently selected.

Also in this section (both create and edit):
- **"Set time of day to do"** toggle — when on, reveals an hours/minutes duration
  picker (`timeTakesToDo`). If set, tapping "I'll Do It Now" in Do Now skips straight
  to a silent countdown of this length instead of first asking how long it'll take.
- If Check First is on: a "Time to Check" duration picker (`timeTakesToCheck`),
  required.

**Save** — "Create Task" / "Save Changes" button, disabled until required fields are
valid (title non-empty; car-maintenance needs a car + at least one trigger;
specific-weekdays needs at least one day selected). Saving recalculates nextDue via the
recurrence/mileage engines and (re)schedules notifications.

**Delete** (edit mode only) — a destructive "Delete Task" button at the bottom, with a
confirmation dialog. Cancels pending notifications for the task.

### 4.3 New Category / Manage Categories

A single merged screen (there is no separate "manage categories" screen):
- Name text field with voice-to-text, "Save" button (disabled while empty).
- If there are any uncategorized tasks, a list of them appears with checkable rows —
  checking a task assigns it to the new category being created, at save time.
- An **"Existing Categories"** section below (styled as a prominent sub-heading) lists
  every non-system category with its task count. The system "Car Maintenance" category
  never appears here (nothing to edit/delete about it). Standard iOS swipe actions on
  each row:
  - Swipe reveals **Delete** (red, trash icon, at the true trailing screen edge) and
    **Edit** (blue, pencil icon, just to its left / closer to the row content).
  - Delete confirms via a dialog stating how many tasks will become uncategorized, then
    can't be undone.
  - Edit opens an alert with a text field to rename in place.

### 4.4 Do Now Flow

Triggered automatically, full-screen, the instant any task becomes "due for a
decision" (§5.1) — not something the user navigates to manually. Takes over the whole
app until resolved. If exactly one task is due, its Do Now action screen (§5.2) shows
directly; if more than one task is due simultaneously, a **queue** screen shows first.

#### 4.4.1 Due Queue (multiple tasks due at once)
- Header "Due Now", scrollable list of cards, one per due task, sorted by nextDue
  ascending.
- Each card: title, category (if any), and a status label — "Time's Up" (doing/
  checking-now countdown expired), "Snooze Ended", "Overdue", or "Due Now".
- Tapping a card opens that task's full Do Now action screen, with a back button that
  returns to the queue. Resolving a task (any action that changes its status such that
  it's no longer "due for decision") automatically drops it out of the queue.
- When the last due task is resolved, the whole Do Now flow dismisses automatically.

#### 4.4.2 Do Now action screen (single task)
Header "Do Now" (with a back button only when reached from the queue). Shows the task
title and category, then one of three states:

**Standard actions** (the normal case):
- **Done** — opens a small "Add a Note" sheet (optional free-text note, voice-to-text
  supported) before actually completing. Completing: records a TaskDoneItem (with
  mileage-at-completion for car tasks, and wasOnTime = current isOverdue negated),
  clears isOverdue/snooze/deadline, recomputes nextDue via the recurrence or mileage
  engine, and reschedules notifications.
- **"I'll Do It Now"** — if the task has a configured "time takes to do", immediately
  starts a silent countdown of that length. Otherwise first shows an hours/minutes
  picker sheet to choose the duration, then starts the countdown. Status becomes
  `doingNow`; a local "Are you done?" prompt is scheduled to fire when the countdown
  ends.
- **"I'll Check It Now"** (only if the task is Check First) — same idea using
  `timeTakesToCheck`; status becomes `checkingNow`; ends with a "Did you check it?"
  prompt instead.
- **Snooze** — tap = snooze for the user's configured default duration; hold reveals a
  menu of the 4 configured Snooze Options to pick a different duration. Sets status to
  `snoozed`, marks the task overdue, reschedules notifications for the new time.
- **"Do It This Evening"** — a plain (non-hold) button. Defers to today's configured
  evening time (or tomorrow's, if that time has already passed today). Sets status to
  `deferred`, marks overdue, reschedules.
- **"Do It Tomorrow"** — tap defers to tomorrow at this task's original time-of-day;
  hold reveals "Do It in 2/3/4 Days" alternatives.
- **"Do It This Weekend" / "Do It Next Weekend"** — label flips automatically based on
  whether "now" currently falls inside the weekend window (Saturday 1 AM through
  Sunday, per the configured weekend day/time); tap defers to the next upcoming
  instance of the configured weekend day/time, hold reveals "1/2 Weekends From Now."

Every one of these actions immediately stops any currently-sounding alarm and
reschedules the task's notifications around whatever new date the action implies.

**"Are you done?" state** (after an "I'll Do It Now" countdown expires):
- "Yes, Done" → completes the task exactly like the Done button.
- "I Didn't Do It" → marks the task overdue again, returns it to pending, and — for
  the remainder of this Do Now session only — hides the Done button on subsequent
  views of this task (so the user has to re-decide via a real action, not just
  re-tap Done immediately). This is a transient, non-persisted flag; a fresh due cycle
  later shows Done normally again.

**"Did you check it?" state** (after an "I'll Check It Now" countdown expires):
- "I Checked It" → advances to a second prompt, **"Does it need to be done?"**:
  - "It Needs to Be Done" → returns the task to pending (still due), so the user then
    sees the standard actions to actually do it.
  - "It Does Not Need to Be Done" → completes the task with `wasDone = false` (still
    logged in Past Done, labeled distinctly — see §4.5).
- "I Didn't Check It" → same "mark overdue, hide Done for this session" behavior as
  "I Didn't Do It" above.

### 4.5 Past Done (history tab)

- Header "Past Done".
- Entries are every TaskDoneItem, newest first, grouped as:
  - Current calendar month's entries listed individually, ungrouped, at the top.
  - Earlier months within the current year collapse into one expandable group per
    month (e.g. "July 2026 - 4 tasks"), each showing a count and a chevron that
    rotates on expand.
  - Prior calendar years each collapse into a single expandable group per year (e.g.
    "2025 - 41 tasks").
  - Only one group can be expanded at a time.
- Each entry row shows: task title (or "Deleted Task" if the task itself was since
  deleted — history persists independently), completion date/time, and a caption line
  with: category name, "Done" or "Checked — Not Needed" (for check-first tasks, based
  on wasDone), mileage at completion (for car tasks), and the task's current streak
  ("N in a row on time," only if ≥2). The optional note is shown below if present.
- Empty state ("No Past Tasks") when there's no history yet.

### 4.6 Settings

- **Notification warning** (only shown if notifications aren't authorized) — a warning
  message plus an "Open Settings" button linking to system notification settings.
  Rechecked every time the app returns to the foreground.
- **Alarm** section — Alarm Sound picker (System Default / Chime / Bell Classic / Bell
  Heavy), Alarm Duration stepper (how long the foreground alarm loops before giving up).
- **Snooze** section — Default Snooze duration stepper, plus the 4 configurable Snooze
  Option rows (each independently steppable, can't be set to duplicate another option's
  value). Footer explains these populate the Snooze button's hold-menu.
- **Defer Defaults** section — "This Evening" time picker; "This Weekend Day" segmented
  Saturday/Sunday picker; "This Weekend Time" picker (range-constrained differently per
  chosen day — Saturday allows 6 AM–11:59 PM, Sunday allows midnight–9 PM, reflecting
  an overall "the weekend" window of Sat 6 AM through Sun 9 PM).
- **Appearance** section — Theme segmented picker: Light / Dark / Retro (§10).
- **Widget** section — a "Home Screen Widget" on/off toggle. Footer clarifies this only
  hides/shows the widget's *content*, since the OS gives no way for the app to actually
  add/remove the widget itself — the widget shows a neutral "Widget Turned Off" state
  instead of task data when off. To physically remove the widget the user must long-
  press it and choose Remove Widget themselves.
- **Cars** section (only shown if any car exists) — a navigable list of every car,
  each opening its edit screen.

All of the above (except the notification warning and Cars list, which are
read-only/derived) persist live to the single AppSettings row as soon as changed — no
separate save button on this screen. The Theme value stays in sync bidirectionally
with the header's theme-switch button (§10), which shares the same underlying setting.

### 4.7 Car Edit (Settings → Cars → a car)

- Name field (voice-to-text).
- "Current Mileage" quick-entry field + Save button — records a new MileageEntry
  timestamped now, and triggers backfill of interpolated entries for any skipped
  months (§6.2).
- Read-only "Monthly Estimate" display, if one exists (derived, not directly editable
  here — see §6.1).
- "Mileage History" list — every recorded entry (both user-entered and
  system-estimated), newest first, showing date and mileage.

### 4.8 New Car

Reached from the task form's Car Maintenance section when creating a car-maintenance
task with no car yet selected (or none exist at all, which auto-opens this).
- Name field (voice-to-text), required.
- Optional "Current Mileage" + "Estimated Miles per Month" fields. Miles-per-month
  becomes required the moment a current mileage is entered (can't have one without the
  other). Both may be left blank entirely.
- Saving creates the car and, if a mileage was given, one initial MileageEntry.

### 4.9 Mileage Prompt

A non-dismissable full-screen card, shown (when nothing is currently due for Do Now)
whenever a car's mileage is due to be asked for per its prompting schedule (§6.3):
- "What's [Car Name]'s Current Mileage?" heading.
- A numeric field pre-filled with the current best estimate.
- Save button (disabled until a number is entered) — records the entry, triggers
  backfill of any skipped months, and recalculates + reschedules every car-maintenance
  task tied to that car (since a new data point can shift the monthly average and
  therefore every trigger date).

---

## 5. Do Now / Due-Decision Logic

### 5.1 What makes a task "due for a decision"

This is the single rule that drives both the full-screen alarm takeover and the Do Now
queue. A task is due for a decision when:

- Status is `doingNow` or `checkingNow`: due once `doingNowDeadline` has passed.
- Status is `snoozed`: due once `snoozeUntil` has passed.
- Status is `pending`, `active`, or `deferred`: due once `nextDue` has passed.

**Important, non-obvious rule:** the `isOverdue` display flag deliberately does **not**
factor into this check. `isOverdue` gets set to true unconditionally the instant the
user snoozes or defers a task (it's what makes those rows show red in the list), but
those actions also always set a legitimate *future* target date/time. If overdue-ness
were also treated as "still due right now," the app would immediately reopen the Do Now
screen the moment a user finished deferring/snoozing — the exact opposite of what
either action means. Only the actual computed date having passed re-triggers a
decision.

### 5.2 What happens when something becomes due

- The main screen polls due-state periodically (every ~15 seconds while the app is
  open) in addition to reacting immediately to data changes and app foreground/
  background transitions, since due-ness is a function of wall-clock time, not just
  data.
- The instant one or more tasks are due, the full-screen Do Now flow presents itself
  and a looping alarm sound starts (unless one is already playing). The alarm plays in
  the foreground only, for up to the configured Alarm Duration, and stops the moment
  any Do Now action is taken (this is "alarm until the user interacts").
- Background/backgrounded delivery of the "this is due" alert is handled by scheduled
  local notifications instead (§7), since a foreground-only audio loop can't run while
  the app isn't frontmost.

---

## 6. Recurrence & Mileage Math

### 6.1 Calendar recurrence (non-mileage tasks)

If the task has never been completed, `nextDue` is simply `firstOccurrence` — whatever
the user entered. Once anchored to a real completion (or a seeded backdated one from
"Last Done"/"Start Now" at creation), `nextDue` steps forward from the most recent
completion's date according to the recurrence type:

| Type | Next-due calculation |
|---|---|
| Daily | +1 day |
| Weekly | +7 days |
| Biweekly | +14 days |
| Monthly | +1 month |
| Every 6 Months | +6 months |
| Annually | +1 year |
| 1st of Month | the next 1st-of-month strictly after the anchor |
| Nth Weekday of Month | the next occurrence of "the Nth (or Last) [weekday]" strictly after the anchor, searching up to 24 months ahead |
| Specific Weekdays | the next date, within 14 days, whose weekday is in the selected set |
| One Time | never recurs — nextDue becomes null after completion |

The time-of-day of the resulting date always matches the time-of-day of the anchor
date used (i.e. recurrence shifts the calendar day, not the clock time — except
1st-of-month and nth-weekday, whose time-of-day carries over from the completion time).

### 6.2 Mileage estimation

- **Monthly average** for a car: if 2+ mileage entries exist, a straight line between
  the earliest and latest entry (`(latest - earliest miles) / months between`).
  Otherwise falls back to the user's manually entered monthly estimate.
- **Estimated current mileage** at any given date: `last entry's mileage + (months
  since that entry × monthly average)`. Falls back to the car's initial mileage if it
  has no entries at all yet.
- **Backfill**: whenever a new mileage entry is recorded more than one month after the
  previous real entry, the gap months each get an automatically-inserted, linearly
  interpolated entry (flagged as system-estimated, not user-entered), so the mileage
  history/graph has no unrealistic month-over-month jumps.

### 6.3 Mileage prompting schedule

Per car, starting from its creation month (month 1): prompted every month for months
1–3, every other month for months 4–9, every 3rd month from month 10 onward. Never
prompted twice in the same calendar month regardless of the above (skipped if an entry
already exists for the current month).

### 6.4 By-mileage task next-due calculation

For a car-maintenance task with a mileage trigger, a time trigger, or both:
- **Mileage-driven date**: reference mileage (the mileage at the task's most recent
  completion if any, else the car's initial mileage, else its current estimate) plus
  the trigger amount, converted to a projected calendar date using the car's monthly
  average.
- **Time-driven date**: the most recent completion date (or the task's firstOccurrence
  if never completed) plus the trigger's month count.
- If both triggers are configured, the **earlier** of the two dates is used.
- If a mileage trigger is configured but there isn't yet enough data to project a date
  (no entries, no initial mileage, no monthly estimate) and there's no time trigger to
  fall back on, `nextDue` is left null (silence) until enough data exists — it
  deliberately does *not* fall back to a stale past date, which would otherwise make
  the task permanently appear overdue.

### 6.5 Streaks

A task's current streak is the count of consecutive completions, counting backward
from the most recent, that each have `wasOnTime = true`. It stops counting the moment
it hits a completion that wasn't on time. Displayed (list row, Do Now queue implicitly
via card status, Past Done rows) only when ≥ 2.

---

## 7. Notifications / Alarm Scheduling

Whenever a task's controlling date (`nextDue`, `snoozeUntil`, or a defer target) is
set, its previously scheduled notifications are cancelled and, if the new date is in
the future, a fresh batch is scheduled:
- One notification exactly at the due date/time.
- Five more staggered follow-up notifications, 5 minutes apart after that (i.e. +5,
  +10, +15, +20, +25 minutes) — so a backgrounded app keeps nagging instead of alerting
  once and going silent. This is a deliberate design differentiator: the app is meant
  to be persistent/aggressive about surfacing due tasks, not a polite one-shot
  reminder.
- Marked as "time-sensitive" so they can punch through most device Focus/Do-Not-
  Disturb filters (no elevated "critical alert" entitlement is used — regular
  Do-Not-Disturb behavior is otherwise respected).
- A separate, single "deadline prompt" notification is scheduled for the "I'll Do It
  Now" / "I'll Check It Now" countdown's end ("Are you done?" / "Did you check it?"),
  independent of the main due-date notification batch.
- All of a task's pending notifications are cancelled outright when the task is
  deleted.

---

## 8. Voice-to-Text Input

Every free-text entry field in the app (task title, category name, car name, done
note) is paired with a microphone button that transcribes speech into that field live
as the user talks, using on-device speech recognition. States: idle mic icon, a filled/
active mic icon plus an animated "Listening..." indicator while capturing, and a
"muted" icon if permission was denied — tapping in the denied state surfaces an alert
explaining why and offering to open system permission settings. Microphone/speech
permission is only requested the first time the mic button is actually tapped, not
proactively on screen load.

---

## 9. Home Screen Widget (iOS-specific — platform-dependent feature)

A small/medium home-screen widget showing the next 3 upcoming tasks (title + relative
time until due), each row deep-linking back into the app directly to that task's edit
form. Refreshes on a ~15-minute timer plus immediately whenever the app changes task
data or the widget on/off setting. Reads from the same underlying data store as the
main app (shared storage). If the user has turned the widget off in Settings, it shows
a neutral "Widget Turned Off" placeholder instead of real data — the OS provides no way
for the app to actually add or remove a placed widget, so "off" can only mean "hide the
content," not "remove the widget." On a platform without an equivalent widget surface
(or where widget on/off doesn't need special-casing), this whole section — and the
`widgetEnabled` setting — can be dropped without affecting anything else in the spec.

---

## 10. Theming

Three selectable visual themes: **Light**, **Dark**, **Retro**. The choice is a single
global setting (not per-view), switchable both from a dedicated control in the main
header bar (cycles through the three on tap) and from the Settings screen's segmented
picker — both write to and read from the same underlying value, kept in sync live.
Beyond visual styling (colors, typography, corner radii), theme has no effect on
behavior anywhere in the app.

---

## 11. Notable Business Rules Worth Preserving in a Port

These are easy to get subtly wrong; each was arrived at by fixing a real bug during
development, so they're called out explicitly:

1. **`isOverdue` is purely cosmetic.** It must never be treated as "this task is due
   right now" — only a task's actual `nextDue`/`snoozeUntil`/`doingNowDeadline` having
   passed means that. See §5.1.
2. **A just-recorded completion must be used immediately**, not re-derived from
   whatever the task's completion-history relationship happens to already reflect at
   that exact instant — recompute nextDue using the completion you just created as an
   explicit input, not by re-reading history after the fact. (This was the direct cause
   of a "the alarm keeps going off right after I tap Done" bug.)
3. **A mileage-only trigger with no mileage data yet must leave `nextDue` null**, not
   fall back to a stale date — a stale past date reads as "permanently overdue."
4. **"Start Now" / "Last Done" must not treat the seeded backdated completion's own
   date as the new anchor for display purposes** — `firstOccurrence` for a task created
   this way should represent the first *future* alarm (i.e. the freshly computed
   nextDue), not the backdated completion date itself.
5. **Streak "on time" status is captured at completion time**, not recomputed
   retroactively from the live overdue flag — because that flag gets cleared
   immediately after every completion and can't be read back later.
