# Resonance Breathing App — Design Document

**Date:** 2026-02-20
**Platform:** iOS (SwiftUI) + watchOS companion
**Status:** Approved

## Overview

A native iOS/watchOS app that guides users through resonance breathing exercises with real-time HRV biofeedback. The app features an Apple Breathe-style flower petal bloom animation, real-time adaptive breathing pace optimization, and continuous Apple Watch haptic feedback.

## System Architecture

```
Apple Watch (watchOS)              iPhone (iOS)
┌─────────────────────┐           ┌──────────────────────────┐
│  - HealthKit workout │  ──────> │  - Bloom animation (SwiftUI) │
│  - HR + R-R intervals│  Watch   │  - HRV analysis engine       │
│  - Haptic engine     │  Conn.   │  - Adaptive breathing pacer  │
│  - Breathing timer   │  <────── │  - Swift Charts (HRV viz)    │
│                      │  Params  │  - SwiftData (persistence)   │
└─────────────────────┘           └──────────────────────────┘
```

### Data Flow

1. watchOS app starts a HealthKit workout session for continuous HR + R-R interval access
2. R-R intervals stream to iPhone via WatchConnectivity framework
3. iPhone computes HRV metrics (RMSSD) and coherence score in real-time
4. Adaptive pacer adjusts breathing rate based on coherence trends
5. Updated breathing parameters sent back to Watch for haptic timing
6. Watch delivers continuous haptic patterns for inhale/hold/exhale

### Technology Stack

- **SwiftUI** — All UI on both iPhone and Watch
- **HealthKit** — Heart rate + R-R interval data from Apple Watch
- **WatchConnectivity** — Real-time bidirectional data streaming
- **Core Animation / SwiftUI Animations** — Flower petal bloom effect
- **Swift Charts** — Real-time HRV waveform visualization
- **SwiftData** — Session history and settings persistence
- **WKHapticType** — watchOS haptic feedback patterns

## Adaptive Breathing Algorithm

### Goal

Find the user's resonance breathing frequency (typically 4.5–7 bpm) by maximizing HRV coherence in real-time.

### HRV Metrics

- **RMSSD**: Root Mean Square of Successive Differences of R-R intervals. Computed over a sliding 30-second window. Primary short-term HRV metric.
- **Coherence Score**: Spectral analysis of HR oscillation — measures how synchronized heart rate variability is with the breathing pattern. Scale: 0–100%.

### Adaptation Logic

Per breathing cycle:
1. Collect R-R intervals from sliding 30-second window
2. Compute RMSSD and coherence score
3. Compare coherence to previous 3 cycles (moving average)
4. Decision:
   - Coherence improving → maintain current rate
   - Coherence declining → adjust rate ±0.1 bpm in the direction that previously improved coherence
   - No clear trend → try alternating direction

### Session Phases

1. **Calibration** (0–2 min): Breathe at default 5.5 bpm. Establish baseline RMSSD and coherence.
2. **Exploration** (2–5 min): Systematically vary rate between 4.5–7 bpm. Identify peak coherence zone.
3. **Resonance Lock** (5 min+): Lock onto the optimal rate. Fine-tune with ±0.1 bpm micro-adjustments.

### Breathing Pattern

- **Inhale**: 4–5 seconds (adjusts with rate)
- **Hold** (optional): 0–2 seconds
- **Exhale**: 5–7 seconds (always ≥ inhale duration)
- Inhale:exhale ratio approximately 4:6

## Visual Design

### Main Session Screen

```
┌──────────────────────────────┐
│  ♡ 68 bpm    RMSSD: 42ms    │  ← Live metrics bar
│  Coherence: ●●●●○  (80%)    │
├──────────────────────────────┤
│                              │
│        [Flower Bloom]        │  ← Hero animation
│                              │
│       INHALE  4.2s           │  ← Phase + countdown
│                              │
├──────────────────────────────┤
│  [HRV Waveform Chart]       │  ← Swift Charts, 60s window
│  Rate: 5.5 bpm  ⟳ adapting  │
└──────────────────────────────┘
```

### Flower Petal Bloom Animation

- 6–8 overlapping ellipses arranged radially (Apple Breathe style)
- **Inhale**: Petals expand outward with spring animation; color shifts cool blue → warm teal
- **Hold**: Petals gently pulse at full size with soft glow
- **Exhale**: Petals contract smoothly; color returns to cool blue
- **Coherence feedback**: Higher coherence = more vibrant glow; lower = muted colors

### Color Palette

- Background: Deep navy/dark (#0A0E1A)
- Petals: Gradient from soft blue (#4A90D9) to teal (#2DD4BF)
- High coherence glow: Warm white/gold accent
- Data text: Light gray on dark (#E0E7FF)
- Charts: Teal line on dark background

## Haptic Design (Apple Watch)

All haptics are **continuous** patterns so the user feels the full inhale/exhale without looking.

- **Inhale** (4–5s): Repeating `WKHapticType.directionUp` taps that **accelerate** — start at 0.8s intervals, end at 0.3s intervals. Feels like a wave building.
- **Hold** (0–2s): Steady `WKHapticType.click` at even 0.6s intervals.
- **Exhale** (5–7s): Repeating `WKHapticType.directionDown` taps that **decelerate** — start at 0.3s intervals, end at 0.8s intervals. Feels like a wave receding.
- **Phase transitions**: 0.2s silence between phases for tactile separation.

The Watch runs the haptic timing loop independently after receiving breathing parameters from the phone. This allows the app to work even when the iPhone screen is off.

## App Screens

### 1. Home Screen
- "Begin Session" button (prominent)
- Last session summary card (date, duration, resonance rate, avg coherence)
- HRV trend mini-chart (last 7–30 days)

### 2. Active Session Screen
- Bloom animation (hero)
- Live metrics bar (HR, RMSSD, coherence)
- HRV waveform chart (bottom)
- Phase label + countdown timer
- End session button (subtle, top corner)

### 3. Session Summary Screen
- Duration, average HR, average RMSSD
- Peak coherence score and at what breathing rate
- Discovered resonance frequency
- Comparison delta vs. previous session
- "Save" / "Discard" actions

### 4. History Screen
- List of past sessions (date, duration, coherence, resonance rate)
- Trend charts: RMSSD over time, coherence over time
- Filter by date range

### 5. Settings Screen
- Default session duration (5, 10, 15, 20 min presets + custom)
- Default starting breathing rate
- Haptic feedback toggle + intensity
- Whoop integration (future — placeholder)

## Data Model (SwiftData)

### BreathingSession
- `id: UUID`
- `date: Date`
- `duration: TimeInterval`
- `averageHR: Double`
- `averageRMSSD: Double`
- `peakCoherence: Double`
- `resonanceRate: Double` (breaths per minute)
- `phases: [SessionPhase]` (calibration, exploration, resonance)

### SessionDataPoint
- `timestamp: Date`
- `hr: Double`
- `rmssd: Double`
- `coherence: Double`
- `breathingRate: Double`

### UserSettings
- `defaultDuration: TimeInterval`
- `defaultBreathingRate: Double`
- `hapticsEnabled: Bool`
- `hapticIntensity: Double`

## Scope & Non-Goals

### In Scope (MVP)
- SwiftUI iOS app + watchOS companion
- Flower bloom breathing animation
- Real-time HR + R-R streaming via WatchConnectivity
- RMSSD computation + coherence scoring
- Adaptive breathing rate algorithm (3-phase)
- Continuous Apple Watch haptics
- Session persistence + history
- Basic trend visualization

### Out of Scope (Future)
- Whoop API integration (historical recovery data)
- Guided meditation audio
- Social/sharing features
- Apple Health export
- iPad / Mac support
- Siri shortcuts
- Widgets / Live Activities
