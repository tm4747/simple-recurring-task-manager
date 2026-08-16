# Simple Recurring Task Manager — Product Requirements Document

**Version:** 1.0
**Platform:** iOS (Swift / SwiftUI / SwiftData)
**Profit Model:** Free tier (all features below). Paid tier TBD in future release.
**Data Persistence:** Local-only (SwiftData). Architecture must be CloudKit-compatible for future sync (UUIDs as primary keys, no unique constraints CloudKit can't handle). Cloud sync will be a future paid-tier feature.
**AI API Usage:** User-provided API keys (Anthropic, OpenAI, Grok) — not used in MVP but architecture should not preclude it.

---

## App Summary

A task alarm app that lets users create one-time or recurring tasks with flexible scheduling (time-based, weekday-based, mileage-based for car maintenance). When a task becomes due, the app aggressively notifies the user via alarm and notification. The user must then deal with the task: mark it done, snooze it, defer it, or start working on it now. All completed task instances are stored for history, streaks, and future dashboards.

**Core differentiator:** This is not a passive checklist. It actively alarms and pesters the user until they deal with the task.

---

## Reference Apps

Claude Code has access to sibling projects that must be referenced for UI patterns:

- **`../SimpleTimer`** — Reference for: theme system & theme selector button, Settings screen layout, bottom navigation tab bar layout, snooze duration settings UI, voice-to-text input implementation (mic icon, 2-second silence auto-cancel)
- **`../SimpleBoxingTimer`** — Reference for: Past Done / history view (items grouped by month and year, matching the "Past Workouts" pattern)

**Action:** Before building any phase that touches these patterns, read the referenced app's source to replicate look, feel, and implementation.

---

## Navigation & Layout

Bottom tab bar (matching `../SimpleTimer` convention):

| Tab | Icon | View |
|-----|------|------|
| **Tasks** | Checklist icon | Main task list / Do Now view |
| **Past Done** | Clock/history icon | Completed task history |
| **Settings** | Gear icon | App settings |

The **theme selector button** should be placed in the same position and style as `../SimpleTimer`.

A **"+"** button on the Tasks tab creates new tasks.

---

## Data Model Overview

### Car
- `id`: UUID (primary key)
- `name`: String (required — e.g., "My Honda Civic")
- `initial_mileage`: Int? (optional at creation)
- `monthly_mileage_estimate`: Int? (user-provided estimate)
- `created_at`: Date
- `updated_at`: Date

### MileageEntry
- `id`: UUID
- `car_id`: UUID (FK → Car)
- `mileage`: Int
- `recorded_at`: Date
- `is_user_entered`: Bool (true = user entered, false = system-estimated)

### Category
- `id`: UUID
- `name`: String
- `is_system`: Bool (true for "Car Maintenance", false for user-created)
- `created_at`: Date

### TaskItem
- `id`: UUID
- `title`: String
- `category_id`: UUID? (FK → Category, nullable = uncategorized)
- `car_id`: UUID? (FK → Car, nullable — only for car maintenance tasks)
- `is_check_first`: Bool (default false — toggle for "inspect and do if necessary")
- `recurrence_type`: Enum — `one_time`, `daily`, `weekly`, `biweekly`, `monthly`, `biannually`, `annually`, `first_of_month`, `nth_weekday_of_month`, `specific_weekdays`, `by_mileage`
- `recurrence_config`: JSON/Dictionary — stores type-specific config (see Recurrence Patterns below)
- `first_occurrence`: Date (date/time of first alarm)
- `next_due`: Date? (calculated next alarm date/time)
- `time_takes_to_do`: TimeInterval? (optional — hours/minutes, up to 72 hours)
- `time_takes_to_check`: TimeInterval? (required if `is_check_first` is true)
- `mileage_trigger`: Int? (e.g., every 5000 miles)
- `time_trigger_months`: Int? (e.g., every 24 months — "whichever comes first" with mileage)
- `is_overdue`: Bool (default false — turns true when task is deferred/snoozed or "I didn't do it")
- `status`: Enum — `pending`, `active`, `snoozed`, `deferred`, `doing_now`, `checking_now`
- `snooze_until`: Date?
- `doing_now_deadline`: Date? (when the "time takes to do/check" expires)
- `created_at`: Date
- `updated_at`: Date

### TaskDoneItem
- `id`: UUID
- `task_id`: UUID (FK → TaskItem)
- `completed_at`: Date
- `was_done`: Bool (true = actually performed the work, false = checked and determined not needed — for check-first tasks)
- `note`: String? (free text, voice-to-text enabled)
- `mileage_at_completion`: Int? (for car tasks)

### SnoozeOption
- `id`: UUID
- `label`: String (e.g., "5 minutes")
- `duration_seconds`: Int
- `sort_order`: Int

### AppSettings
- `default_snooze_seconds`: Int (default: 300 = 5 min)
- `evening_time`: Date/Time (default: 6:00 PM, configurable 2:00 PM – 11:00 PM)
- `weekend_default_time`: Date/Time (default: Saturday 9:00 AM, configurable Saturday 6:00 AM – Sunday 9:00 PM)
- `selected_theme`: String
- `alarm_sound`: String (system default or custom sound name)
- `alarm_duration_seconds`: Int (default: 300 = 5 min)

---

## Recurrence Patterns

The `recurrence_config` dictionary stores pattern-specific data:

| Type | Config Keys | Example |
|------|-------------|---------|
| `one_time` | (none) | Fire once at `first_occurrence` |
| `annually` | (none) | Same date each year |
| `biannually` | (none) | Every 6 months |
| `monthly` | (none) | Same day each month |
| `first_of_month` | (none) | 1st of each month |
| `nth_weekday_of_month` | `week_number`: 1-5 (5=last), `weekday`: 1-7 | "3rd Wednesday of each month" |
| `specific_weekdays` | `weekdays`: [1,3,5] | "Every Mon, Wed, Fri" |
| `by_mileage` | (uses `mileage_trigger` and optionally `time_trigger_months` on TaskItem) | "Every 5000 miles or 6 months" |

**Next-due calculation:** When cadence is changed on a task that has been completed at least once, the new `next_due` is calculated from the most recent `TaskDoneItem.completed_at` date. If the task has never been completed, `next_due` remains as the user originally set it.

---

## Mileage Tracking System (Car Maintenance)

### Per-car mileage prompting schedule:

When a user has any car maintenance tasks, prompt for **each car's** current mileage on this schedule:

1. **Months 1–3:** Prompt at the 1st of each month
2. **Months 4–9:** Prompt every other month. Non-prompted months use monthly average.
3. **Month 10+:** Prompt every 3 months. Non-prompted months use monthly average.

The user also provides an initial **monthly mileage estimate** when creating a car. This estimate is used until 2+ months of real data exist, at which point a calculated average replaces it.

### Mileage-based alarm triggering:

For a car with `current_estimated_mileage` and a task with `mileage_trigger` of X miles:
- Calculate estimated date when mileage threshold will be reached using monthly average
- Set `next_due` to that estimated date
- Recalculate whenever new mileage data is entered

If the task also has a `time_trigger_months` value, the alarm fires at **whichever comes first** — mileage or time.

### Current mileage estimation:

`estimated_current_mileage = last_entered_mileage + (months_since_entry × monthly_average)`

Monthly average = calculated from all `MileageEntry` records for that car (once 2+ entries exist), otherwise uses user's initial estimate.

---

## Alarm & Notification Behavior

### When a task becomes due:

1. **App foregrounded:** Alarm sound plays for up to 5 minutes (or until user interacts). The Do Now view appears.
2. **App backgrounded:** Repeating local notifications with alarm sound. Persistent notification banner. Continue firing repeated notifications until the user foregrounds the app and deals with the task.
3. **Respect Do Not Disturb:** Yes. Alarms follow system DND settings.
4. **Alarm sound:** System default alarm + a few bundled custom sounds. Selectable in Settings.

### Multiple simultaneous tasks:

If multiple tasks are due at once, the app shows a **card-based queue view**:
- Each active task appears as a card with task title, category, and due info
- Tapping a card navigates to the full Do Now action view for that task
- After the user takes action (done, snooze, defer, etc.), they return to the card queue
- Tasks that have been dealt with (snoozed, deferred, completed) disappear from the queue
- Snoozed tasks reappear when their snooze expires

---

## Do Now Action View

When a task is due and the user foregrounds the app, they see the Do Now view with these actions:

### Standard Task Actions:

| Button | Behavior | Hold Behavior |
|--------|----------|---------------|
| **Done** | Mark complete. Create `TaskDoneItem`. Prompt for optional note (voice-to-text). Update `next_due` for recurring tasks. | — |
| **I'll Do It Now** | Prompt for `time_takes_to_do` if not already set (hour/minute picker, max 72h). Start countdown. After duration, follow-up alarm: "Are you done?" → "Yes, done" or "I didn't do it". | — |
| **Snooze** | Snooze for default duration (from Settings). | **Hold:** Reveal configurable snooze options (default: 5 min, 30 min, 1 hr, 3 hr). These values are configurable in Settings. |
| **Do It This Evening** | Defer to evening time (default 6 PM, configurable 2 PM–11 PM in Settings). | — |
| **Do It Tomorrow** | Defer to tomorrow at original task time. | **Hold:** Reveal "Do it in 2 days", "Do it in 3 days", "Do it in 4 days" |
| **Do It Next Weekend** | Defer to configured weekend time (default Sat 9 AM). If current time is Mon 12:00 AM – Fri 11:59 PM: button says "Do It This Weekend". If current time is Sat 1:00 AM – Sun 12:59 AM: button says "Do It Next Weekend". | **Hold (always):** "Do it [next +1] weekend", "Do it [next +2] weekends from now" (always 2 additional options beyond whatever the button label says) |

### Check-First Task Actions (when `is_check_first` is true):

Same as above, plus an additional primary button:

| Button | Behavior |
|--------|----------|
| **I'll Check It Now** | Start countdown using `time_takes_to_check`. After duration, follow-up prompt: "Did you check it?" → **"I checked it"** or **"I didn't check it"** |

If **"I checked it"**:
- Prompt: **"It needs to be done"** or **"It does not need to be done"**
- If needs to be done → returns to full Do Now action view (Done, I'll Do It Now, Snooze, etc.)
- If does not need to be done → mark as Done. Create `TaskDoneItem` with `was_done = false`. Prompt for optional note.

If **"I didn't check it"**:
- Returns to full Do Now action view (minus "Done" — same as the "I didn't do it" flow)

### "I Didn't Do It" flow:

When the "I'll Do It Now" timer expires and the user selects "I didn't do it":
- Task becomes `is_overdue = true` (highlighted in red throughout the app)
- User sees the same action options **except "Done"** (since they didn't do it): Snooze, Do It This Evening, Do It Tomorrow (with hold options), Do It This/Next Weekend (with hold options), I'll Do It Now

### Overdue / Red Highlighting:

A task is highlighted in red when:
- It was snoozed
- It was deferred (evening, tomorrow, weekend, X days)
- The user selected "I'll Do It Now", the timer expired, and they clicked "I didn't do it"
- The user selected "I'll Check It Now", the timer expired, and they clicked "I didn't check it"

The red highlight persists until the task is marked Done.

---

## Task List View (Home — Tasks Tab)

### Priority routing:

1. If there are active Do Now tasks → show the Do Now view (single task) or multi-task card queue
2. Otherwise → show the task list

### Task list layout:

- Sorted by `next_due` date (soonest first)
- Grouped by category
- Overdue tasks sort to the top with red highlight
- Category filter dropdown at the top of the list (above the task list). Options: "All", plus each category. Default: "All"
- **"+" button** to create a new task

### Task interactions:

- Tap a task → edit view
- Swipe left → delete (with confirmation)
- Overdue tasks display with red background/border

---

## Category Management

### Built-in categories:
- **Car Maintenance** (system, non-deletable)

### User-created categories:

**Creating a new category** (via "+" button next to category filter dropdown):
1. Text input for category name
2. Below the input: list of all uncategorized tasks with checkboxes
3. User enters name, optionally checks tasks to assign
4. "Save" creates the category and assigns selected tasks

**Creating a category from the New/Edit Task view:**
1. Category dropdown on the task form
2. "+" button next to the dropdown
3. Opens the New Category view (same as above)
4. After saving the new category, returns to the task form with the new category pre-selected

**Assigning/unassigning categories:**
- Every task has an optional `category_id`
- Tasks can be uncategorized (null `category_id`)
- Changing a task's category retroactively affects how its `TaskDoneItem` records display in history (history shows the task's *current* category)

---

## Car Management

### Adding a car:

When a user taps "+" to create a task and selects the "Car Maintenance" category, they are prompted to select a car or add a new one.

**New car form:**
- Car name (required)
- Current mileage (optional but prompted)
- Estimated miles driven per month (required if mileage is entered)

### Car maintenance task creation:

- Select which car this task is for (dropdown of user's cars)
- Enter mileage trigger (e.g., "Every 5,000 miles") — optional
- Enter time trigger (e.g., "Every 24 months") — optional
- **At least one trigger (mileage or time) is required**
- If both are entered, alarm fires at whichever comes first
- Car name displays on the task in the task list

### Multiple cars:

Each car has independent mileage tracking, monthly averages, and mileage prompting schedules.

---

## Past Done View (History Tab)

Reference `../SimpleBoxingTimer` "Past Workouts" view for implementation pattern.

### Layout:
- Items grouped by **month and year** (e.g., "August 2026", "July 2026")
- Each item shows: task title, category, completion date/time, note (if any), `was_done` indicator for check-first tasks
- Scrollable list, most recent first

### Streak display:
- For recurring tasks, show streak count (consecutive on-time completions)
- e.g., "Clean gutters — 4 months in a row on time"
- A completion counts as "on time" if the task was not marked overdue (red) when completed

---

## Settings

Reference `../SimpleTimer` for Settings screen layout and UI patterns.

### Settings sections:

**Alarm**
- Alarm sound picker (system default + bundled custom sounds)
- Alarm duration (default: 5 minutes)

**Snooze**
- Default snooze duration (default: 5 minutes)
- Snooze option 1 (default: 5 minutes)
- Snooze option 2 (default: 30 minutes)
- Snooze option 3 (default: 1 hour)
- Snooze option 4 (default: 3 hours)
- (Reference `../SimpleTimer` snooze settings UI for look and feel)

**Defer Defaults**
- "This evening" time (default: 6:00 PM, range: 2:00 PM – 11:00 PM)
- "This weekend" time (default: Saturday 9:00 AM, range: Saturday 6:00 AM – Sunday 9:00 PM)

**Appearance**
- Theme selector (copy from `../SimpleTimer`)

**Widget**
- Toggle home screen widget on/off
- Widget shows next 3 upcoming tasks

**Cars** (only visible if user has cars)
- List of cars with current estimated mileage
- Tap to edit car name, view mileage history, manually enter mileage

---

## Home Screen Widget

- **Optional** — user can add/remove via iOS widget system
- Shows next 3 upcoming tasks with title, category, and time until due
- Tapping a task opens the app to that task
- Should be easy to remove (standard iOS widget removal)

---

## Voice-to-Text Input

Reference `../SimpleTimer` implementation for the "label" / voice announcement field.

### Behavior:
- Mic icon next to text input fields
- Tap mic to start voice input
- 2 seconds of silence auto-cancels and commits the text
- Apply to all non-numeric text inputs throughout the app:
  - Task title
  - Task done note
  - Category name
  - Car name

---

## Themes

Copy the complete theme system and theme selector button from `../SimpleTimer`:
- Same themes available
- Same selector button placement and behavior
- Applied consistently across all views

---

## App Badge

- App icon badge count = number of overdue/currently-due tasks
- Updates when tasks become due, are completed, or are deferred

---

## Build Phases

Each phase is designed to be executed independently in Claude Code as a single prompt. Complete each phase fully before moving to the next.

---

### Phase 1: Project Setup & Data Model

**Scope:** Create the Xcode project, define all SwiftData models, and establish the app skeleton.

**Tasks:**
1. Create new iOS project "SimpleRecurringTaskManager" with SwiftUI + SwiftData
2. Implement all data models: `Car`, `MileageEntry`, `Category`, `TaskItem`, `TaskDoneItem`, `SnoozeOption`, `AppSettings`
3. Use UUIDs as primary keys on all models (CloudKit-compatible)
4. Avoid unique constraints that CloudKit cannot handle
5. Create the `RecurrenceType` enum and `recurrence_config` storage
6. Seed the "Car Maintenance" system category on first launch
7. Seed default `SnoozeOption` values (5 min, 30 min, 1 hr, 3 hr)
8. Seed default `AppSettings`
9. Create a basic `ModelContainer` configuration
10. Read `../SimpleTimer` to understand the project structure, then mirror the same structure conventions

**Acceptance:** App launches, models compile, default data seeds on first run.

---

### Phase 2: Theme System, Navigation & App Shell

**Scope:** Set up the tab bar, theme system, and empty view shells.

**Tasks:**
1. Copy the theme system from `../SimpleTimer` — all themes, theme model, theme selector button, same placement
2. Implement bottom tab bar matching `../SimpleTimer` layout convention: Tasks | Past Done | Settings
3. Create empty view shells for: TaskListView, PastDoneView, SettingsView
4. Create the "+" button on the Tasks tab for new task creation
5. Apply theming to all views consistently

**Acceptance:** App shows themed tab bar with 3 tabs, theme selector works, "+" button visible on Tasks tab.

---

### Phase 3: Settings Screen

**Scope:** Build the full Settings screen with all configurable values.

**Tasks:**
1. Read `../SimpleTimer` Settings implementation for layout and UI patterns
2. Build Settings sections: Alarm, Snooze, Defer Defaults, Appearance, Widget toggle, Cars
3. Implement snooze duration settings matching `../SimpleTimer` snooze settings UI
4. Alarm sound picker (system default + custom sounds)
5. Evening time picker (2 PM – 11 PM range)
6. Weekend time picker (Saturday 6 AM – Sunday 9 PM range)
7. Cars section (visible only if cars exist) — list cars, tap to edit, manually enter mileage
8. Persist all settings via `AppSettings` model

**Acceptance:** All settings are editable and persist across app restarts.

---

### Phase 4: Category Management

**Scope:** CRUD for categories, category filter on task list.

**Tasks:**
1. Create New Category view: name input (with voice-to-text mic icon), uncategorized task checklist, Save button
2. Category filter dropdown at top of Tasks tab (All + each category)
3. Allow category deletion (with confirmation — reassign tasks to uncategorized)
4. Protect "Car Maintenance" system category from deletion
5. Implement voice-to-text on category name input matching `../SimpleTimer` label field implementation (mic icon, 2-second silence auto-cancel)

**Acceptance:** User can create, filter by, and delete categories. Voice-to-text works on name input.

---

### Phase 5: Task Creation & Editing

**Scope:** Full task creation form with all recurrence patterns, editing, and deletion.

**Tasks:**
1. New Task form with fields: title (voice-to-text), category dropdown (with "+" to create new category inline), is_check_first toggle, recurrence type picker, first occurrence date/time picker, time_takes_to_do (optional, hour/minute picker up to 72h), time_takes_to_check (required if is_check_first, hour/minute picker)
2. Dynamic recurrence config UI based on selected type:
   - One-time: just date/time
   - Annual/biannual/monthly: date/time
   - First of month: time only
   - Nth weekday of month: week number picker (1st–5th/Last) + weekday picker
   - Specific weekdays: multi-select weekday picker (Mon–Sun)
   - By mileage: car selector, mileage trigger input, optional time trigger (months)
3. Car maintenance flow: when category = "Car Maintenance", show car selector (or "Add New Car" which opens car creation form), show mileage/time trigger fields. At least one trigger required.
4. Edit task: tap task in list → pre-populated form. Recalculate `next_due` on save (anchored to last completion date if task has been completed, otherwise keep user-entered date)
5. Delete task: swipe-to-delete with confirmation dialog
6. Voice-to-text on task title input

**Acceptance:** User can create tasks with all recurrence types, edit them, and delete them. Car maintenance tasks link to a car. Next-due recalculates correctly on edit.

---

### Phase 6: Task List View & Display

**Scope:** The main task list with sorting, grouping, filtering, and overdue highlighting.

**Tasks:**
1. Task list sorted by `next_due` (soonest first)
2. Tasks grouped by category with section headers
3. Overdue tasks (`is_overdue = true`) sort to the absolute top with red highlight (red background/border)
4. Category filter dropdown at top filters the list
5. Each task row shows: title, car name (if car task), next due date/time, category, overdue indicator
6. App badge count = number of due + overdue tasks

**Acceptance:** Task list displays correctly sorted/grouped/filtered. Overdue items are red and pinned to top. Badge count updates.

---

### Phase 7: Alarm Scheduling & Notifications

**Scope:** Schedule local notifications for task due dates and implement alarm sound playback.

**Tasks:**
1. Schedule local notifications for each task's `next_due` date
2. When task is due and app is foregrounded: play alarm sound for up to 5 minutes (or until user interacts)
3. When task is due and app is backgrounded: fire repeating local notifications with alarm sound
4. Respect Do Not Disturb system settings
5. Reschedule notifications when tasks are created, edited, completed, snoozed, or deferred
6. Bundle system default alarm sound + a few custom sounds (selectable in Settings)
7. Handle notification permissions request on first launch

**Acceptance:** Notifications fire at correct times. Alarm plays when app is foregrounded. Repeating notifications when backgrounded. Sound selection works.

---

### Phase 8: Do Now Flow — Standard Tasks

**Scope:** The full Do Now interaction flow for standard (non-check-first) tasks.

**Tasks:**
1. Do Now view with action buttons: Done, I'll Do It Now, Snooze (tap = default, hold = options), Do It This Evening, Do It Tomorrow (hold = 2/3/4 days), Do It This/Next Weekend (hold = additional weekend options)
2. Weekend button logic: Mon–Fri shows "Do It This Weekend"; Sat 1:00 AM – Sun 12:59 AM shows "Do It Next Weekend". Hold always reveals 2 additional further-weekend options.
3. "Done" flow: create `TaskDoneItem`, prompt for optional note (voice-to-text), update `next_due` for recurring tasks
4. "I'll Do It Now" flow: prompt for `time_takes_to_do` if not set (hour/minute picker, max 72h). Start countdown. After duration, follow-up alarm: "Are you done?" → "Yes, done" (→ Done flow) or "I didn't do it" (→ mark overdue, show all options except Done)
5. Snooze: apply duration, reschedule notification, mark overdue
6. Defer (evening/tomorrow/weekend/X days): set new `next_due`, reschedule notification, mark overdue
7. Multi-task card queue: when multiple tasks are due, show card view. Tap card → Do Now view. After action, return to queue with dealt-with tasks removed.
8. Priority routing on app open: if active Do Now tasks exist → show Do Now or card queue. Otherwise → task list.

**Acceptance:** Complete Do Now flow works for all standard task actions. Multi-task queue works. Snooze/defer correctly reschedule. Overdue marking works.

---

### Phase 9: Do Now Flow — Check-First Tasks

**Scope:** The check-first ("inspect and do if necessary") variant of the Do Now flow.

**Tasks:**
1. For tasks with `is_check_first = true`, add "I'll Check It Now" button to Do Now view (alongside all standard buttons)
2. "I'll Check It Now": start countdown using `time_takes_to_check`. After duration, prompt: "Did you check it?" → "I checked it" or "I didn't check it"
3. "I checked it" → prompt: "It needs to be done" or "It does not need to be done"
   - Needs to be done → return to full Do Now view (all standard options)
   - Does not need to be done → create `TaskDoneItem` with `was_done = false`, prompt for optional note, update `next_due`
4. "I didn't check it" → mark overdue, show all options except "Done" (same as "I didn't do it" flow)

**Acceptance:** Check-first flow works end-to-end. `was_done` boolean correctly recorded. Overdue marking works for "didn't check" path.

---

### Phase 10: Car Maintenance & Mileage System

**Scope:** Mileage tracking, prompting schedule, and mileage-based alarm calculation.

**Tasks:**
1. Mileage prompting system: track each car's creation date. Prompt per the schedule (monthly for 3 months, bimonthly for 6 months, quarterly after). Show prompt as a non-dismissable card/modal on app open when mileage is due.
2. Per-car mileage entry: simple input with current estimated mileage pre-filled, user confirms or corrects
3. Monthly average calculation: after 2+ `MileageEntry` records exist for a car, calculate true monthly average. Before that, use user's initial estimate.
4. Mileage estimation: `estimated_current_mileage = last_entered_mileage + (months_since × monthly_average)`
5. Mileage-based task triggering: calculate estimated date when `mileage_trigger` will be reached, set `next_due` to that date. Recalculate whenever new mileage is entered.
6. Dual-trigger tasks (mileage + time): `next_due` = whichever trigger date comes first
7. `MileageEntry` records: store each entry with `is_user_entered` flag. System-estimated entries are created for non-prompted months.
8. Record `mileage_at_completion` on `TaskDoneItem` for car tasks

**Acceptance:** Mileage prompting fires on schedule per car. Monthly average calculates correctly. Mileage-based tasks trigger at the right estimated time. Dual triggers work (whichever first).

---

### Phase 11: Past Done History & Streaks

**Scope:** The history view and streak tracking.

**Tasks:**
1. Read `../SimpleBoxingTimer` Past Workouts implementation for grouping pattern
2. Past Done view: all `TaskDoneItem` records, grouped by month and year, most recent first
3. Each history item shows: task title, category (current category of parent task), completion date/time, note, `was_done` indicator for check-first tasks, mileage at completion (for car tasks)
4. Streak calculation: for each recurring task, count consecutive on-time completions (task was not `is_overdue` when completed). Display streak on task in the task list and in history.
5. Category grouping in history follows the parent task's *current* category (if user re-categorizes a task, history items reflect the new category)

**Acceptance:** History view matches `../SimpleBoxingTimer` grouping pattern. Streaks calculate and display correctly. Category changes propagate to history display.

---

### Phase 12: Home Screen Widget

**Scope:** Optional iOS home screen widget showing upcoming tasks.

**Tasks:**
1. Create WidgetKit extension
2. Widget shows next 3 upcoming tasks (title, time until due, category)
3. Tapping a task deep-links into the app to that task
4. Widget updates on task changes (completion, creation, edit, snooze, defer)
5. Handles empty state ("No upcoming tasks")
6. Matches app theme if feasible, otherwise uses clean default styling

**Acceptance:** Widget displays on home screen with correct data. Tapping opens the app. Updates reflect task changes. User can add/remove widget via standard iOS flow.

---

### Phase 13: Voice-to-Text & Polish

**Scope:** Ensure voice-to-text is implemented on all text inputs, final polish pass.

**Tasks:**
1. Read `../SimpleTimer` voice-to-text implementation (mic icon on label/voice announcement field)
2. Apply to all non-numeric text inputs: task title, task done note, category name, car name
3. Behavior: tap mic to start, 2 seconds of silence auto-cancels and commits text
4. Polish pass: consistent theming across all views, animation/transition consistency, error handling for edge cases (e.g., notification permissions denied, no cars when creating car task)
5. Test all recurrence pattern calculations
6. Test overdue state transitions
7. Test mileage estimation accuracy
8. Verify app badge count accuracy

**Acceptance:** Voice-to-text works on all text fields. App feels polished and consistent. No crashes on edge cases.

---

## Edge Cases & Notes

- **Notification permissions denied:** Show a gentle prompt explaining why notifications matter for this app. Link to Settings to enable.
- **No cars exist when selecting Car Maintenance category:** Redirect to car creation flow before task creation continues.
- **Task deleted while snoozed/deferred:** Cancel any pending notifications for that task.
- **App not opened for days:** On open, any tasks whose `next_due` has passed should appear as overdue in the Do Now queue.
- **Recurring task completed early:** `next_due` still calculates from the completion date, not the original due date. This means doing something early shifts the cycle forward.
- **Time zone changes:** Store all dates in UTC. Display in local time. Recalculate notifications on significant time change events.
