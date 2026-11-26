# Kinetic Focus Dial — Complete Android App Blueprint

A complete product, UI/UX, and Android technical specification for a minimalist focus and Pomodoro app built around a rotating 3-layer mechanical dial.

---

## 1. Product Vision & Positioning

Most Android focus timers fall into one of two extremes: gamified or heavy task suites like [Forest](https://play.google.com/store/apps/details?id=cc.forestapp&hl=en) and [Focus To-Do](https://play.google.com/store/apps/details?id=com.superelement.pomodoro&hl=en), or ultra-plain digital utilities like [Goodtime](https://goodtime.tools/).

**Core Goal:** Combine the calm, zero-clutter reliability of a dedicated minimalist timer with a tactile, mechanical visual identity (the rotating disk and gradient window) that feels rewarding to use and immediately stands out on Google Play.

**Design Pillars:**
* **Calm First:** One primary screen with zero ads, no social feeds, and no forced login.
* **Tactile & Physical:** The dial responds to touch (dragging the rim, subtle haptic clicks, smooth rotation) like a real desk object.
* **Honest Utility:** Visual flair never compromises readability, background timer accuracy, or battery life.

---

## 2. The Kinetic Dial: Visual & Interaction Specification

The centerpiece of the app is a circular 3-layer widget inspired by a physical rotating-aperture clock.

### 2.1 Three-Layer Stack Architecture

| Layer | Visual Role | Motion Behavior |
| :--- | :--- | :--- |
| **Layer 1: Gradient Under-Disk (Back)** | Holds the mood and phase color sweep (cool tones for focus, warm tones for rest, deep indigo/violet for endless flow). | Rotates smoothly (`180°` or `360°`) as a session progresses or transitions between Focus and Rest phases. |
| **Layer 2: Top Mask Disk with Cutout Slot (Middle)** | Clean matte circular face (off-white in Light Mode, matte charcoal/pure OLED black in Dark Mode) with a horizontal pill-shaped cutout window showing Layer 1 underneath. | Remains cleanly oriented horizontally so text stays readable; rotates briefly with a damped spring animation when switching modes. |
| **Layer 3: Dual Hand Assembly (Front)** | **Primary Live Hand** (solid, high-contrast pointer) + **Ghost Marker** (thin, low-opacity hand or outer rim notch). | Live Hand always sweeps continuously with real elapsed/remaining time. Ghost Marker sits at the target or benchmark angle. |

### 2.2 Solving Contrast & Readability Traps

* **Gradient Contrast Guard:** Because the under-disk shifts across bright and dark colors, place a subtle frosted or semi-transparent dark scrim pill behind the mode name inside the cutout slot, or lock each mode to a curated contrast-safe gradient palette so text always meets WCAG 4.5:1 readability.
* **Subtle Digital Readout (`MM:SS`):** Place a crisp, low-emphasis monospace readout directly beneath the mode name inside the slot (or tucked neatly below the center pivot). Users can toggle "Pure Analog" in Options, where tapping the dial briefly fades in the exact digits for 3 seconds.
* **Direct-Manipulation Gestures:**
  * **Drag Outer Rim (when Idle):** Rotates the planned duration in 1-minute or 5-minute increments with crisp haptic ticks.
  * **Tap Cutout Slot (when Idle):** Cycles smoothly between `Pomodoro`, `Focus`, and `Endless` modes.
  * **Double-Tap Dial Center (when Running):** Adds `+5 min` quick extension (optional toggle in Options).

---

## 3. Core Focus Modes & Behavior

To avoid confusing users, the **Live Hand always represents active time** across all three modes, while the **Ghost Marker represents the target or benchmark**.

| Mode | Live Hand Behavior | Ghost Marker Role | Cutout Gradient Theme | Completion Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **Pomodoro** | Sweeps smoothly through the current Focus or Break interval (`0°` to `360°`). | Marks the full cycle end (`12 o'clock`) plus subtle perimeter dots for completed rounds (e.g., `2/4`). | Cool Blue/Cyan (Focus) shifting to Warm Amber/Coral (Break). | Plays gentle chime/vibration; transitions to Short Break or Long Break (manual start or auto-start). |
| **Focus Session** | Sweeps continuously from start (`0°`) toward the planned duration so the app never looks frozen. | Marks the user's planned end time on the dial. | Deep Slate/Emerald sweep. | Plays completion chime, logs session, and returns cleanly to Idle. |
| **Endless (Flow)** | Counts upward continuously around a 60-minute dial scale (adds a subtle outer ring lap indicator after 60 min). | Anchored at the **previous Endless session's duration** (or personal best) so the user watches the Live Hand physically pass their record. | Deep Violet shifting to Gold once the Ghost Marker is passed. | Runs until manually stopped; optionally calculates an earned break budget (e.g., 20% of focus time, similar to [Goodtime's Flow mode](https://play.google.com/store/apps/details?id=com.apps.adrcotfas.goodtime&hl=en_IN)). |

### 3.1 Session State Machine

Every timer session moves strictly through five deterministic states:

1. **`IDLE`**: Mode and duration can be edited freely; rim dragging enabled; no background service running.
2. **`RUNNING`**: Foreground service active; timestamp anchored (`startEpochMs` + `targetEndEpochMs`); DND rule active if enabled.
3. **`PAUSED`**: Foreground service persists with "Paused" notification; elapsed duration frozen; `accumulatedPauseMs` tracked.
4. **`PHASE_TRANSITION`**: Reached when a Pomodoro Focus or Break block hits zero; triggers alarm/vibration and waits for tap (or auto-advances if configured).
5. **`COMPLETED` / `ABORTED`**: Writes a structured record to local storage (sessions under a configurable minimum, e.g., `< 1 min`, are discarded to keep stats clean), clears DND rule, and stops the foreground service.

---

## 4. Screen-by-Screen UI Layout

### 4.1 Main Timer Screen (Default Home)
* **Top Bar (Minimal):**
  * Left: Current **Label Chip** (e.g., `• Coding`, `• Study`, `• General`) — tapping opens a fast bottom sheet to pick or create a colored label without cluttering the screen.
  * Right: **Stats Icon** — opens the Statistics & History sheet.
* **Center Stage (70% of viewport):**
  * The **Kinetic Dial** centered with generous breathing room.
  * Subtle session-round indicator dots directly underneath when in Pomodoro mode (e.g., `● ● ○ ○`).
* **Bottom Control Dock (3 Clean Actions):**
  * **Left — Options Button:** Opens the two-tier Options bottom sheet or screen.
  * **Center — Play / Pause Button:** Large, primary circular/pill button; morphs smoothly between Play and Pause icons.
  * **Right — Skip / Stop Button:** Requires a **0.8-second hold** (with a circular progress ring filling around the button) to skip to the next phase or end an active session, preventing accidental resets.

### 4.2 Options Architecture (High Range, Zero Clutter)
Because you want deep customization without breaking the clean feel, divide Options into two clear tiers:

* **Tier 1 — Quick Controls (Always Visible at Top):**
  * **Smart Presets Strip:** One-tap profiles (`Classic 25/5`, `Deep 50/10`, `Sprint 15/3`, `Flow Count-Up`, plus user-saved custom presets).
  * **Core Toggles:** Auto Do Not Disturb, Keep Screen On, Ambient Sound (Off / Rain / White Noise / Mechanical Tick).
* **Tier 2 — Collapsible Advanced Accordions (Expanded Only When Needed):**
  * **Timing & Cycles:** Custom Focus length (1–180 min), Short Break (1–30 min), Long Break (5–60 min), Sessions before Long Break (2–8), Auto-start Breaks, Auto-start Focus, Strict Mode (disable pause).
  * **Dial & Visuals:** Theme (System / Light / OLED Pure Black), Digital Readout (Always On / Tap to Peek / Off), Endless Mode Ghost Target (Last Session / Personal Best / Daily Average), Haptic Rim Ticks (On/Off).
  * **Alerts & Notifications:** Completion sound picker, Vibration pattern, Screen flash alert (for silent study spaces), Persistent notification style.
  * **Data & Backup:** Manual session entry, Export history to CSV or JSON, Import local backup.

### 4.3 Lightweight Statistics & History Sheet
* **Summary Strip:** Today's focus time, current daily streak, and completed sessions.
* **Visual Breakdown:** Simple 7-day bar chart and time-per-label ring chart (avoiding overwhelming 7-chart dashboards unless the user taps "Detailed View").
* **Session Log:** Reverse-chronological list with mode, label, duration, and swipe-to-edit/delete so users can fix forgotten timers.

---

## 5. Android Technical Architecture

### 5.1 Drift-Free Timestamp Engine
Never compute remaining time by decrementing a counter every second (background throttling causes severe drift). Instead:
* Store `sessionStartUtcMs`, `plannedDurationMs`, `pauseStartUtcMs`, and `totalPausedMs`.
* Compute display state purely as a function of `SystemClock.elapsedRealtime()` (immune to manual clock changes) or UTC timestamps.
* Re-sync the dial angle immediately on `onResume` / app foregrounding.

### 5.2 Background Execution & Exact Alarms (Android 14–16 Ready)
* **Foreground Service:** Run an active session inside an [Android Foreground Service](https://developer.android.com/develop/background-work/services/fgs) declared with `android:foregroundServiceType="specialUse"` ([Android Foreground Service Types](https://developer.android.com/develop/background-work/services/fgs/service-types)), accompanied by the required manifest `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` explanation for Google Play review (user-initiated countdown/focus timer with ongoing notification).
* **Ongoing Notification:** Display live chronometer countdown/count-up plus inline `Pause/Resume` and `Skip` action buttons directly in the notification shade.
* **Exact Phase-End Alarms:** Schedule phase completion using [`AlarmManager.setExactAndAllowWhileIdle()`](https://developer.android.com/develop/background-work/services/alarms) so the end-of-session chime fires reliably even in Doze mode. Because [`SCHEDULE_EXACT_ALARM` is denied by default on Android 14+](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms), check `canScheduleExactAlarms()` and gently guide the user to grant it only if needed, with a fallback to the running foreground service.

### 5.3 Do Not Disturb Compliance (Android 15+ Rule)
* Apps targeting Android 15 (API 35) and higher [can no longer directly modify global Do Not Disturb state](https://developer.android.com/about/versions/15/behavior-changes-15) via `NotificationManager.setInterruptionFilter()`.
* **Correct Approach:** Register a dedicated `AutomaticZenRule` (a Focus Mode rule owned by your app) via `NotificationManager.addAutomaticZenRule()` and toggle it active/inactive when a focus session starts and ends. On older Android versions (API 24–34), fall back gracefully to standard DND access.

### 5.4 Local-First Storage Schema
Keep all data local in SQLite (e.g., Drift/sqflite in Flutter, or Room in Kotlin) with zero mandatory cloud dependency:
* **`presets`**: `id`, `name`, `mode`, `focus_sec`, `short_break_sec`, `long_break_sec`, `cycles_before_long_break`, `auto_start_break`, `auto_start_focus`.
* **`labels`**: `id`, `name`, `color_hex`, `is_archived`, `created_at`.
* **`sessions`**: `id`, `mode`, `label_id`, `started_at`, `ended_at`, `planned_sec`, `actual_sec`, `completed` (bool), `notes`.
* **`app_settings`**: Key-value preferences (theme, haptics, readout visibility, DND enabled, sound choice).

### 5.5 Recommended Tech Stack (Flutter)
Since you already build Android apps in Flutter, Flutter is an ideal fit for this UI:
* **Dial Rendering:** `CustomPainter` driven by a `Ticker` / `AnimationController` for silky 60–120fps rotation, smooth gradient shaders (`SweepGradient` / `LinearGradient`), and crisp clipping (`Path.combine` or `Canvas.clipRRect`) for the cutout slot.
* **Native Android Bridge:** Small Kotlin `MethodChannel` (or a maintained foreground service plugin) for the `specialUse` foreground service, `AlarmManager`, and Android 15 `AutomaticZenRule` DND handling.
* **State Management:** Riverpod or Bloc to cleanly separate the `TimerEngine` state machine from UI animations.

---

## 6. Phased Build Roadmap

| Phase | Scope | Exit Criteria |
| :--- | :--- | :--- |
| **Phase 1: Interactive Core (MVP)** | 3-layer Kinetic Dial (`CustomPainter`), rim-drag duration selector, Play/Pause + Hold-to-Skip, Pomodoro + Focus + Endless modes, timestamp-based engine. | Dial feels smooth at 60+ fps; timers stay accurate when switching apps or locking screen. |
| **Phase 2: Android Reliability** | `specialUse` Foreground Service + ongoing notification controls, exact alarm chimes, `AutomaticZenRule` DND toggle, local SQLite session logging. | Survives 60-minute background sessions in Doze mode without being killed. |
| **Phase 3: Polish & Retention (V1.0)** | Two-tier Options sheet with presets, colored session labels, lightweight stats sheet, OLED dark theme, haptic detents, CSV/JSON export. | Clean, bug-free daily driver ready for closed beta / Google Play launch. |
| **Phase 4: Post-Launch (V1.5)** | Optional ambient soundscapes (rain/ticking), home-screen widget, Wear OS companion dial, optional strict app-blocker. | Expands retention without bloating the core screen. |

---

## 7. Open Decisions to Lock Before Coding

Finalize these four choices before writing the first line of code:

1. **App Name & Identity:** Pick a short, memorable name that hints at motion or clarity (e.g., *Aperture*, *Dial*, *Solstice*, *Orbit* — verify Google Play uniqueness first).
2. **Framework Lock:** Confirm **Flutter + small Kotlin native bridge** vs. pure **Kotlin + Jetpack Compose**.
3. **Distraction Strategy for V1.0:** Ship with **DND Focus Rule only** (lightweight, Play-Store friendly, zero battery drain) or invest early in an **Accessibility/UsageStats App Blocker** (higher Play Store review scrutiny and battery impact, as noted in [Forest comparisons](https://pompomapp.cc/blog/best-pomodoro-app-pompom-vs-focus-to-do-vs-forest)).
4. **Monetization Model:** Free & open-source with an optional one-time "Supporter / Pro" unlock (similar to [Goodtime's model](https://itsfoss.com/news/goodtime/)) vs. completely free portfolio/utility release.
