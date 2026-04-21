# NumberFlutter - Features and Design

This document first lists the currently available features, then describes the app's broad design direction.

## Current Features

### 1) Core gameplay

- Tap-to-gain main loop on the `Generators` screen.
- Real-time big number display with compact notation.
- Idle generation ticker with visible per-second output.
- Floating gain text and pulse feedback on interactions.

### 2) Progression systems

- Upgrade system with two branches: `CLICK` and `IDLE`.
- Purchase quantity modes: `1x`, `10x`, `100x`, `MAX`.
- Milestone-based scaling for upgrade effects.
- Click mechanics include Momentum, Probability Strike, Kinetic Synergy, and Overclock.

### 3) Prestige system (current revamp)

- Prestige screen with simplified single-action flow.
- Requirement check + reward preview for next prestige.
- Prestige points display.
- Total prestige counter display.
- Prestige confirmation dialog and prestige animation overlay.
- Prestige shop button and shop UI removed from active screen flow.

### 4) Account, profile, and social

- Optional sign-in (email/password, Google, Apple).
- Offline-first play without account required.
- Profile editor with display name, country, and city.
- Leaderboards with scopes: Global, Country, City.
- Location-aware ranking views based on profile data.

### 5) Persistence and sync

- Local save/load through SharedPreferences.
- Offline gains calculation and return dialog.
- Cloud sync through Supabase when authenticated.
- Manual sync trigger in `System`.
- Deterministic conflict resolution (progress score + tie-breakers).

### 6) System controls

- Factory reset flow with confirmation.
- Sign out action when authenticated.
- App/system info panel in `System`.

---

## App Design (Broad)

### 1) Product design intent

NumberFlutter follows a minimalist incremental-game style with a terminal/sci-fi control-panel tone. The experience prioritizes fast feedback, readability of huge numbers, and a clear long-term progression arc from manual tapping into automated growth and prestige loops.

### 2) Experience architecture

The app uses five primary tabs:

- `Generators`: moment-to-moment interaction.
- `Upgrades`: build optimization and spending decisions.
- `Prestige`: long-loop reset and meta progression.
- `Ranks`: social comparison.
- `System`: account, sync, and safety controls.

This separates immediate play, strategy decisions, and account/meta operations cleanly.

### 3) Core UI pattern

Most screens share a common structure:

- top status strip with current number context,
- strong section title hierarchy,
- compact information blocks,
- clear action buttons,
- persistent bottom navigation.

The consistency is intentional to reduce cognitive load while keeping each tab specialized.

### 4) Gameplay loop design

The loop is layered:

1. immediate gains from taps,
2. compounding power through upgrades,
3. tempo modifiers from special mechanics,
4. prestige reset for long-term progression,
5. leaderboard/profile layer for social motivation.

This creates a short-loop (session) + long-loop (meta progression) structure.

### 5) Prestige UX direction

Prestige is intentionally simplified:

- one clear objective (meet requirement),
- one clear action (initiate prestige),
- one concise reward preview,
- persistent prestige progress indicator (total prestiges).

This keeps prestige understandable and avoids extra UI complexity.

### 6) Information design

The UI favors legibility and hierarchy over clutter:

- compact notation for large values,
- explicit labels for rates/costs/progress,
- strong emphasis on primary numbers and actions.

### 7) Data and system design

The architecture is offline-first with optional cloud identity:

- local progression always works,
- sign-in adds sync and leaderboard participation,
- profile/location enriches ranking scopes,
- sync resolves conflicts deterministically.

This allows seamless solo play while supporting cross-device continuity and social features.
# NumberFlutter - App Design Overview

This document describes the broad design of the app (structure, flow, and style), rather than a full implementation checklist.

## 1) Product Design Intent

NumberFlutter is designed as a minimalist incremental game with a strong “terminal/sci-fi control panel” feel. The experience is built around fast interaction, high readability of huge values, and clear progression loops that move from active tapping into automation and long-term prestige.

The main goal of this game is to compete with people from you city, country, or globally, thus creating a fun, competitive and rewarding atmosphere

## 2) Experience Architecture

The app is organized into five primary tabs:

- `Generators`: the core interaction surface for number growth.
- `Upgrades`: progression tuning for click and idle performance.
- `Prestige`: long-run reset loop and meta progression.
- `Ranks`: social comparison via leaderboards.
- `System`: account, persistence, sync, and reset controls.

This creates a clear split between:

- **moment-to-moment play** (`Generators`),
- **build decisions** (`Upgrades`, `Prestige`),
- **metagame + account operations** (`Ranks`, `System`).

## 3) Core UI Pattern

Most screens share a consistent visual skeleton:

- top value/header strip (current number context),
- prominent section title,
- dense but readable data blocks,
- action controls with high-contrast buttons,
- bottom navigation as the global movement layer.

This consistency keeps navigation easy while each tab remains specialized.

## 4) Gameplay Design Loop

The gameplay loop is designed in layers:

1. **Immediate action:** tapping produces instant feedback and gain.
2. **Compounding growth:** upgrades increase click/idle output.
3. **Temporal mechanics:** momentum/overclock/probability effects add texture.
4. **Reset economy:** prestige converts run progress into long-term currency/progression.
5. **Social motivation:** leaderboard visibility and profile identity.

This “short loop + long loop” structure is the core design backbone.

## 5) Prestige UX Design (Current Direction)

Prestige has been simplified to be easier to parse:

- one clear goal (reach requirement, then prestige),
- one clear action (initiate prestige),
- one reward preview (points + next requirement context),
- one persistent meta indicator (total prestige count).

The previous prestige shop entry point is intentionally removed from UI to reduce cognitive load and keep prestige focused.

## 6) Information Design

The app emphasizes legibility for large numbers and dense progression data:

- custom compact number notation for very large values,
- explicit labels for rates and costs,
- progress affordance (purchase states/progress bars),
- visual hierarchy that prioritizes key numbers over decorative elements.

## 7) State and Data Design

The data model is built as offline-first with optional cloud identity:

- local persistence always supports standalone play,
- account sign-in unlocks cloud sync and ranks,
- sync resolves conflicts deterministically using progression scoring,
- profile/location data enables global + local leaderboard scopes.

This ensures the game remains playable without login while still supporting cross-device continuity.

## 8) Interaction and Feedback Design

Feedback is designed to keep play responsive and readable:

- pulsing/floating gain feedback on taps,
- momentum progress bar when relevant,
- offline gains modal after returning,
- prestige confirmation + full-screen reset animation.

Each feedback element maps to a meaningful game-state transition.

## 9) Current System Boundaries

At the design level, the app currently exposes:

- core tap/idle progression,
- upgrade economy,
- prestige progression,
- account/profile/leaderboard systems.

Some legacy logic (such as permanent prestige shop math) still exists in code, but is currently outside the active user-facing design flow.
