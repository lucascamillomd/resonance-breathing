# Resonance Breathing App — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native iOS/watchOS resonance breathing app with real-time HRV biofeedback, adaptive breathing rate optimization, flower petal bloom animation, and Apple Watch haptic guidance.

**Architecture:** Core breathing algorithms live in a local Swift Package (`BreathingCore`) for easy TDD. iOS app uses SwiftUI + SwiftData + Swift Charts. watchOS companion streams HR via WatchConnectivity and drives haptics. XcodeGen generates the project from a YAML spec for reproducible builds.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, Swift Charts, HealthKit, WatchConnectivity, WKHapticType, XcodeGen

---

## Project Structure

```
ResonanceBreathing/
├── project.yml                           # XcodeGen spec
├── Packages/
│   └── BreathingCore/                    # Local Swift Package (testable algorithms)
│       ├── Package.swift
│       ├── Sources/BreathingCore/
│       │   ├── BreathingPhase.swift       # Inhale/Hold/Exhale enum + timing
│       │   ├── BreathingParameters.swift  # Rate, durations, ratio config
│       │   ├── HRVAnalyzer.swift          # RMSSD from R-R intervals
│       │   ├── CoherenceCalculator.swift  # Spectral coherence scoring
│       │   └── AdaptivePacer.swift        # 3-phase rate optimizer
│       └── Tests/BreathingCoreTests/
│           ├── BreathingPhaseTests.swift
│           ├── HRVAnalyzerTests.swift
│           ├── CoherenceCalculatorTests.swift
│           └── AdaptivePacerTests.swift
├── ResonanceBreathing/                   # iOS app target
│   ├── ResonanceBreathingApp.swift
│   ├── Models/
│   │   ├── BreathingSession.swift         # SwiftData
│   │   ├── SessionDataPoint.swift         # SwiftData
│   │   └── UserSettings.swift             # SwiftData
│   ├── Views/
│   │   ├── HomeView.swift
│   │   ├── SessionView.swift
│   │   ├── SummaryView.swift
│   │   ├── HistoryView.swift
│   │   └── SettingsView.swift
│   ├── Components/
│   │   ├── BloomAnimationView.swift       # Petal bloom with coherence glow
│   │   ├── PetalShape.swift               # Custom Shape for one petal
│   │   ├── HRVChartView.swift             # Swift Charts waveform
│   │   ├── MetricsBarView.swift           # HR + RMSSD + coherence bar
│   │   └── CoherenceDotsView.swift        # ●●●●○ indicator
│   ├── Services/
│   │   ├── WatchConnector.swift           # WCSession delegate (phone side)
│   │   ├── SessionManager.swift           # Orchestrates a breathing session
│   │   └── BreathingTimer.swift           # Drives phase transitions + animation
│   ├── Theme/
│   │   └── AppTheme.swift                 # Colors, fonts, spacing constants
│   ├── Info.plist
│   └── Assets.xcassets/
├── ResonanceBreathingWatch Watch App/    # watchOS target
│   ├── ResonanceBreathingWatchApp.swift
│   ├── WatchSessionView.swift
│   ├── WorkoutManager.swift               # HealthKit HR + R-R streaming
│   ├── HapticEngine.swift                 # Continuous haptic patterns
│   ├── PhoneConnector.swift               # WCSession delegate (watch side)
│   └── Info.plist
└── docs/plans/
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Packages/BreathingCore/Package.swift`
- Create: `Packages/BreathingCore/Sources/BreathingCore/BreathingCore.swift` (placeholder)
- Create: `Packages/BreathingCore/Tests/BreathingCoreTests/BreathingCoreTests.swift` (placeholder)
- Create: `project.yml` (XcodeGen spec)
- Create: `ResonanceBreathing/ResonanceBreathingApp.swift`
- Create: `ResonanceBreathing/Info.plist`
- Create: `ResonanceBreathingWatch Watch App/ResonanceBreathingWatchApp.swift`
- Create: `ResonanceBreathingWatch Watch App/Info.plist`

**Step 1: Install XcodeGen**

Run: `brew install xcodegen`
Expected: xcodegen installed (or already installed)

**Step 2: Create the BreathingCore Swift Package**

```swift
// Packages/BreathingCore/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BreathingCore",
    platforms: [.iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "BreathingCore", targets: ["BreathingCore"]),
    ],
    targets: [
        .target(name: "BreathingCore"),
        .testTarget(name: "BreathingCoreTests", dependencies: ["BreathingCore"]),
    ]
)
```

```swift
// Packages/BreathingCore/Sources/BreathingCore/BreathingCore.swift
// Placeholder — real code added in subsequent tasks
public enum BreathingCore {
    public static let version = "0.1.0"
}
```

```swift
// Packages/BreathingCore/Tests/BreathingCoreTests/BreathingCoreTests.swift
import XCTest
@testable import BreathingCore

final class BreathingCoreTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(BreathingCore.version, "0.1.0")
    }
}
```

**Step 3: Verify Swift Package builds and tests pass**

Run: `cd Packages/BreathingCore && swift test`
Expected: "Test Suite 'All tests' passed"

**Step 4: Create XcodeGen project spec**

```yaml
# project.yml
name: ResonanceBreathing
options:
  bundleIdPrefix: com.lucascamillo
  deploymentTarget:
    iOS: "17.0"
    watchOS: "10.0"
  xcodeVersion: "15.0"
  createIntermediateGroups: true

packages:
  BreathingCore:
    path: Packages/BreathingCore

targets:
  ResonanceBreathing:
    type: application
    platform: iOS
    sources:
      - ResonanceBreathing
    dependencies:
      - package: BreathingCore
    settings:
      base:
        INFOPLIST_FILE: ResonanceBreathing/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.lucascamillo.resonancebreathing
        SWIFT_VERSION: "5.9"
    entitlements:
      path: ResonanceBreathing/ResonanceBreathing.entitlements
      properties:
        com.apple.developer.healthkit: true
        com.apple.developer.healthkit.access: []

  ResonanceBreathingWatch Watch App:
    type: application
    platform: watchOS
    sources:
      - "ResonanceBreathingWatch Watch App"
    dependencies:
      - package: BreathingCore
      - target: ResonanceBreathing
        embed: false
    settings:
      base:
        INFOPLIST_FILE: "ResonanceBreathingWatch Watch App/Info.plist"
        PRODUCT_BUNDLE_IDENTIFIER: com.lucascamillo.resonancebreathing.watchkitapp
        SWIFT_VERSION: "5.9"
    entitlements:
      path: "ResonanceBreathingWatch Watch App/ResonanceBreathingWatch.entitlements"
      properties:
        com.apple.developer.healthkit: true
        com.apple.developer.healthkit.access: []
```

**Step 5: Create minimal iOS app entry point**

```swift
// ResonanceBreathing/ResonanceBreathingApp.swift
import SwiftUI
import SwiftData

@main
struct ResonanceBreathingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Resonance Breathing")
            .font(.title)
    }
}
```

```xml
<!-- ResonanceBreathing/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSHealthShareUsageDescription</key>
    <string>Resonance Breathing needs access to your heart rate data to provide real-time HRV biofeedback during breathing sessions.</string>
    <key>NSHealthUpdateUsageDescription</key>
    <string>Resonance Breathing saves workout sessions to track your breathing practice.</string>
</dict>
</plist>
```

**Step 6: Create minimal watchOS app entry point**

```swift
// ResonanceBreathingWatch Watch App/ResonanceBreathingWatchApp.swift
import SwiftUI

@main
struct ResonanceBreathingWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Resonance")
                .font(.headline)
        }
    }
}
```

```xml
<!-- ResonanceBreathingWatch Watch App/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSHealthShareUsageDescription</key>
    <string>Resonance Breathing reads your heart rate during breathing sessions.</string>
    <key>WKCompanionAppBundleIdentifier</key>
    <string>com.lucascamillo.resonancebreathing</string>
</dict>
</plist>
```

**Step 7: Create entitlements files**

```xml
<!-- ResonanceBreathing/ResonanceBreathing.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
</plist>
```

```xml
<!-- ResonanceBreathingWatch Watch App/ResonanceBreathingWatch.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
</plist>
```

**Step 8: Generate Xcode project and verify build**

Run: `xcodegen generate`
Expected: "Generated project ResonanceBreathing.xcodeproj"

Run: `xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 9: Commit**

```bash
git add -A
git commit -m "feat: scaffold Xcode project with iOS + watchOS targets and BreathingCore package"
```

---

### Task 2: BreathingPhase Model & Timing

**Files:**
- Create: `Packages/BreathingCore/Sources/BreathingCore/BreathingPhase.swift`
- Create: `Packages/BreathingCore/Sources/BreathingCore/BreathingParameters.swift`
- Create: `Packages/BreathingCore/Tests/BreathingCoreTests/BreathingPhaseTests.swift`

**Step 1: Write failing tests for BreathingPhase**

```swift
// Packages/BreathingCore/Tests/BreathingCoreTests/BreathingPhaseTests.swift
import XCTest
@testable import BreathingCore

final class BreathingPhaseTests: XCTestCase {

    func testPhaseCycleThroughInhaleHoldExhale() {
        let phase = BreathingPhase.inhale
        XCTAssertEqual(phase.next, .hold)
        XCTAssertEqual(BreathingPhase.hold.next, .exhale)
        XCTAssertEqual(BreathingPhase.exhale.next, .inhale)
    }

    func testDefaultParametersAt5_5BPM() {
        let params = BreathingParameters(breathsPerMinute: 5.5)
        let cycleDuration = params.inhaleDuration + params.holdDuration + params.exhaleDuration
        let expectedCycle = 60.0 / 5.5
        XCTAssertEqual(cycleDuration, expectedCycle, accuracy: 0.01)
    }

    func testExhaleAlwaysLongerThanInhale() {
        for bpm in stride(from: 4.5, through: 7.0, by: 0.5) {
            let params = BreathingParameters(breathsPerMinute: bpm)
            XCTAssertGreaterThanOrEqual(params.exhaleDuration, params.inhaleDuration,
                "Exhale should be >= inhale at \(bpm) bpm")
        }
    }

    func testInhaleExhaleRatioApproximately4to6() {
        let params = BreathingParameters(breathsPerMinute: 5.5)
        let totalBreathing = params.inhaleDuration + params.exhaleDuration
        let inhaleRatio = params.inhaleDuration / totalBreathing
        XCTAssertEqual(inhaleRatio, 0.4, accuracy: 0.05)
    }

    func testParametersClampToValidRange() {
        let tooFast = BreathingParameters(breathsPerMinute: 20.0)
        XCTAssertEqual(tooFast.breathsPerMinute, 7.0) // clamped to max

        let tooSlow = BreathingParameters(breathsPerMinute: 1.0)
        XCTAssertEqual(tooSlow.breathsPerMinute, 4.5) // clamped to min
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Packages/BreathingCore && swift test`
Expected: FAIL — types not found

**Step 3: Implement BreathingPhase and BreathingParameters**

```swift
// Packages/BreathingCore/Sources/BreathingCore/BreathingPhase.swift
import Foundation

public enum BreathingPhase: String, CaseIterable, Sendable {
    case inhale
    case hold
    case exhale

    public var next: BreathingPhase {
        switch self {
        case .inhale: return .hold
        case .hold: return .exhale
        case .exhale: return .inhale
        }
    }

    public var label: String {
        switch self {
        case .inhale: return "INHALE"
        case .hold: return "HOLD"
        case .exhale: return "EXHALE"
        }
    }
}
```

```swift
// Packages/BreathingCore/Sources/BreathingCore/BreathingParameters.swift
import Foundation

public struct BreathingParameters: Sendable, Equatable {
    public static let minBPM: Double = 4.5
    public static let maxBPM: Double = 7.0
    public static let defaultBPM: Double = 5.5
    public static let inhaleRatio: Double = 0.4
    public static let holdRatio: Double = 0.05

    public let breathsPerMinute: Double
    public let inhaleDuration: Double
    public let holdDuration: Double
    public let exhaleDuration: Double

    public init(breathsPerMinute: Double) {
        let clamped = min(max(breathsPerMinute, Self.minBPM), Self.maxBPM)
        self.breathsPerMinute = clamped

        let cycleDuration = 60.0 / clamped
        self.holdDuration = cycleDuration * Self.holdRatio
        let breathingTime = cycleDuration - holdDuration
        self.inhaleDuration = breathingTime * Self.inhaleRatio
        self.exhaleDuration = breathingTime * (1.0 - Self.inhaleRatio)
    }

    /// Adjust rate by a delta (in BPM), clamped to valid range.
    public func adjustedBy(_ delta: Double) -> BreathingParameters {
        BreathingParameters(breathsPerMinute: breathsPerMinute + delta)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Packages/BreathingCore && swift test`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Packages/BreathingCore/Sources/BreathingCore/BreathingPhase.swift \
       Packages/BreathingCore/Sources/BreathingCore/BreathingParameters.swift \
       Packages/BreathingCore/Tests/BreathingCoreTests/BreathingPhaseTests.swift
git commit -m "feat: add BreathingPhase enum and BreathingParameters with timing calculations"
```

---

### Task 3: HRV Analyzer (RMSSD Computation)

**Files:**
- Create: `Packages/BreathingCore/Sources/BreathingCore/HRVAnalyzer.swift`
- Create: `Packages/BreathingCore/Tests/BreathingCoreTests/HRVAnalyzerTests.swift`

**Step 1: Write failing tests for HRVAnalyzer**

```swift
// Packages/BreathingCore/Tests/BreathingCoreTests/HRVAnalyzerTests.swift
import XCTest
@testable import BreathingCore

final class HRVAnalyzerTests: XCTestCase {

    func testRMSSDWithKnownValues() {
        // R-R intervals in milliseconds: [800, 810, 795, 820, 805]
        // Successive diffs: [10, -15, 25, -15]
        // Squared: [100, 225, 625, 225]
        // Mean: 293.75
        // RMSSD: sqrt(293.75) ≈ 17.14
        let analyzer = HRVAnalyzer()
        let intervals: [Double] = [800, 810, 795, 820, 805]
        let rmssd = analyzer.computeRMSSD(rrIntervals: intervals)
        XCTAssertEqual(rmssd, 17.14, accuracy: 0.01)
    }

    func testRMSSDNeedsAtLeastTwoIntervals() {
        let analyzer = HRVAnalyzer()
        XCTAssertNil(analyzer.computeRMSSD(rrIntervals: []))
        XCTAssertNil(analyzer.computeRMSSD(rrIntervals: [800]))
    }

    func testConstantIntervalsGiveZeroRMSSD() {
        let analyzer = HRVAnalyzer()
        let intervals = Array(repeating: 800.0, count: 10)
        let rmssd = analyzer.computeRMSSD(rrIntervals: intervals)
        XCTAssertEqual(rmssd, 0.0, accuracy: 0.001)
    }

    func testSlidingWindowReturnsRecentIntervals() {
        let analyzer = HRVAnalyzer(windowDuration: 5.0) // 5-second window
        // Add intervals totaling more than 5 seconds
        let timestamps: [Double] = [0, 0.8, 1.6, 2.4, 3.2, 4.0, 4.8, 5.6, 6.4]
        let intervals: [Double] = [800, 800, 800, 800, 800, 800, 800, 800, 800]
        for (t, rr) in zip(timestamps, intervals) {
            analyzer.addInterval(rr: rr, timestamp: t)
        }
        let windowed = analyzer.recentIntervals(at: 6.4)
        // Should only include intervals with timestamps within [1.4, 6.4]
        XCTAssertTrue(windowed.count < intervals.count)
        XCTAssertTrue(windowed.count >= 5) // roughly 5s / 0.8s = 6 intervals
    }

    func testRMSSDFromSlidingWindow() {
        let analyzer = HRVAnalyzer(windowDuration: 30.0)
        // Simulate 30+ seconds of data with some variability
        var timestamp = 0.0
        let baseInterval = 800.0
        for i in 0..<50 {
            let rr = baseInterval + Double(i % 5) * 5.0 // 800, 805, 810, 815, 820, 800, ...
            analyzer.addInterval(rr: rr, timestamp: timestamp)
            timestamp += rr / 1000.0
        }
        let rmssd = analyzer.currentRMSSD(at: timestamp)
        XCTAssertNotNil(rmssd)
        XCTAssertGreaterThan(rmssd!, 0)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Packages/BreathingCore && swift test --filter HRVAnalyzerTests`
Expected: FAIL — HRVAnalyzer not found

**Step 3: Implement HRVAnalyzer**

```swift
// Packages/BreathingCore/Sources/BreathingCore/HRVAnalyzer.swift
import Foundation

public final class HRVAnalyzer: @unchecked Sendable {
    private let windowDuration: Double
    private var intervals: [(timestamp: Double, rr: Double)] = []
    private let lock = NSLock()

    public init(windowDuration: Double = 30.0) {
        self.windowDuration = windowDuration
    }

    /// Add a new R-R interval (in milliseconds) with a timestamp (in seconds).
    public func addInterval(rr: Double, timestamp: Double) {
        lock.lock()
        defer { lock.unlock() }
        intervals.append((timestamp: timestamp, rr: rr))
    }

    /// Get R-R intervals within the sliding window ending at `now`.
    public func recentIntervals(at now: Double) -> [Double] {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = now - windowDuration
        return intervals.filter { $0.timestamp >= cutoff }.map(\.rr)
    }

    /// Compute RMSSD from the current sliding window.
    public func currentRMSSD(at now: Double) -> Double? {
        let recent = recentIntervals(at: now)
        return computeRMSSD(rrIntervals: recent)
    }

    /// Compute RMSSD from a given array of R-R intervals (in ms).
    /// Returns nil if fewer than 2 intervals.
    public func computeRMSSD(rrIntervals: [Double]) -> Double? {
        guard rrIntervals.count >= 2 else { return nil }

        var sumSquaredDiffs = 0.0
        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i - 1]
            sumSquaredDiffs += diff * diff
        }
        let mean = sumSquaredDiffs / Double(rrIntervals.count - 1)
        return sqrt(mean)
    }

    /// Clear all stored intervals.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        intervals.removeAll()
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Packages/BreathingCore && swift test --filter HRVAnalyzerTests`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Packages/BreathingCore/Sources/BreathingCore/HRVAnalyzer.swift \
       Packages/BreathingCore/Tests/BreathingCoreTests/HRVAnalyzerTests.swift
git commit -m "feat: add HRVAnalyzer with RMSSD computation and sliding window"
```

---

### Task 4: Coherence Calculator

**Files:**
- Create: `Packages/BreathingCore/Sources/BreathingCore/CoherenceCalculator.swift`
- Create: `Packages/BreathingCore/Tests/BreathingCoreTests/CoherenceCalculatorTests.swift`

**Step 1: Write failing tests for CoherenceCalculator**

```swift
// Packages/BreathingCore/Tests/BreathingCoreTests/CoherenceCalculatorTests.swift
import XCTest
@testable import BreathingCore

final class CoherenceCalculatorTests: XCTestCase {

    func testPerfectlySinusoidalHRGivesHighCoherence() {
        // Simulate HR that oscillates perfectly at the breathing frequency
        let breathingFreqHz = 5.5 / 60.0 // 5.5 bpm in Hz
        let sampleRate = 4.0 // 4 Hz (one sample every 250ms)
        let duration = 30.0
        let numSamples = Int(duration * sampleRate)

        var hrSamples: [Double] = []
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let hr = 70.0 + 5.0 * sin(2.0 * .pi * breathingFreqHz * t)
            hrSamples.append(hr)
        }

        let calc = CoherenceCalculator()
        let score = calc.computeCoherence(
            hrSamples: hrSamples,
            sampleRateHz: sampleRate,
            breathingFreqHz: breathingFreqHz
        )
        XCTAssertGreaterThan(score, 0.7, "Perfect sinusoidal HR should yield high coherence")
    }

    func testRandomHRGivesLowCoherence() {
        var hrSamples: [Double] = []
        for _ in 0..<120 {
            hrSamples.append(Double.random(in: 60...80))
        }

        let calc = CoherenceCalculator()
        let score = calc.computeCoherence(
            hrSamples: hrSamples,
            sampleRateHz: 4.0,
            breathingFreqHz: 5.5 / 60.0
        )
        XCTAssertLessThan(score, 0.3, "Random HR should yield low coherence")
    }

    func testCoherenceScaleIs0To1() {
        let calc = CoherenceCalculator()
        // Even with extreme inputs, score should be clamped 0-1
        let score = calc.computeCoherence(
            hrSamples: Array(repeating: 70.0, count: 120),
            sampleRateHz: 4.0,
            breathingFreqHz: 5.5 / 60.0
        )
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    func testInsufficientSamplesReturnsZero() {
        let calc = CoherenceCalculator()
        let score = calc.computeCoherence(
            hrSamples: [70, 72],
            sampleRateHz: 4.0,
            breathingFreqHz: 5.5 / 60.0
        )
        XCTAssertEqual(score, 0.0)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Packages/BreathingCore && swift test --filter CoherenceCalculatorTests`
Expected: FAIL — CoherenceCalculator not found

**Step 3: Implement CoherenceCalculator**

Uses a simplified DFT (Discrete Fourier Transform) approach — compute power at the breathing frequency vs total power in the resonance band (0.04–0.15 Hz).

```swift
// Packages/BreathingCore/Sources/BreathingCore/CoherenceCalculator.swift
import Foundation

public final class CoherenceCalculator: Sendable {
    /// Minimum samples needed for meaningful spectral analysis (~8 seconds at 4 Hz)
    private static let minSamples = 32

    public init() {}

    /// Compute coherence score (0.0–1.0) measuring how much HR oscillation
    /// is concentrated at the breathing frequency.
    ///
    /// - Parameters:
    ///   - hrSamples: Heart rate values sampled at a regular interval
    ///   - sampleRateHz: Sampling frequency in Hz
    ///   - breathingFreqHz: Current breathing frequency in Hz (bpm / 60)
    /// - Returns: Coherence score 0.0 (no coherence) to 1.0 (perfect coherence)
    public func computeCoherence(
        hrSamples: [Double],
        sampleRateHz: Double,
        breathingFreqHz: Double
    ) -> Double {
        guard hrSamples.count >= Self.minSamples else { return 0.0 }

        let n = hrSamples.count
        let mean = hrSamples.reduce(0, +) / Double(n)
        let centered = hrSamples.map { $0 - mean }

        // Compute power spectrum via DFT for the resonance band (0.04–0.15 Hz)
        let freqResolution = sampleRateHz / Double(n)
        let minBin = max(1, Int(0.04 / freqResolution))
        let maxBin = min(n / 2, Int(0.15 / freqResolution))

        guard maxBin > minBin else { return 0.0 }

        // Target bin for breathing frequency (with ±1 bin tolerance)
        let targetBin = Int(round(breathingFreqHz / freqResolution))
        let targetRange = max(minBin, targetBin - 1)...min(maxBin, targetBin + 1)

        var targetPower = 0.0
        var totalPower = 0.0

        for k in minBin...maxBin {
            let power = dftPowerAtBin(k: k, signal: centered)
            totalPower += power
            if targetRange.contains(k) {
                targetPower += power
            }
        }

        guard totalPower > 0 else { return 0.0 }
        return min(max(targetPower / totalPower, 0.0), 1.0)
    }

    /// Compute power at a single DFT bin.
    private func dftPowerAtBin(k: Int, signal: [Double]) -> Double {
        let n = signal.count
        var real = 0.0
        var imag = 0.0
        let angle = 2.0 * .pi * Double(k) / Double(n)
        for i in 0..<n {
            real += signal[i] * cos(angle * Double(i))
            imag -= signal[i] * sin(angle * Double(i))
        }
        return (real * real + imag * imag) / Double(n * n)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Packages/BreathingCore && swift test --filter CoherenceCalculatorTests`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Packages/BreathingCore/Sources/BreathingCore/CoherenceCalculator.swift \
       Packages/BreathingCore/Tests/BreathingCoreTests/CoherenceCalculatorTests.swift
git commit -m "feat: add CoherenceCalculator with DFT-based spectral coherence scoring"
```

---

### Task 5: Adaptive Pacer (3-Phase Rate Optimizer)

**Files:**
- Create: `Packages/BreathingCore/Sources/BreathingCore/AdaptivePacer.swift`
- Create: `Packages/BreathingCore/Tests/BreathingCoreTests/AdaptivePacerTests.swift`

**Step 1: Write failing tests for AdaptivePacer**

```swift
// Packages/BreathingCore/Tests/BreathingCoreTests/AdaptivePacerTests.swift
import XCTest
@testable import BreathingCore

final class AdaptivePacerTests: XCTestCase {

    func testStartsInCalibrationPhase() {
        let pacer = AdaptivePacer()
        XCTAssertEqual(pacer.sessionPhase, .calibration)
        XCTAssertEqual(pacer.currentParameters.breathsPerMinute, BreathingParameters.defaultBPM)
    }

    func testTransitionsToExplorationAfterCalibrationDuration() {
        let pacer = AdaptivePacer(calibrationDuration: 10.0, explorationDuration: 20.0)
        pacer.update(coherence: 0.5, elapsedTime: 11.0)
        XCTAssertEqual(pacer.sessionPhase, .exploration)
    }

    func testTransitionsToResonanceLockAfterExploration() {
        let pacer = AdaptivePacer(calibrationDuration: 10.0, explorationDuration: 20.0)
        // Push past calibration + exploration
        pacer.update(coherence: 0.5, elapsedTime: 31.0)
        XCTAssertEqual(pacer.sessionPhase, .resonanceLock)
    }

    func testExplorationSweepsBreathingRate() {
        let pacer = AdaptivePacer(calibrationDuration: 2.0, explorationDuration: 60.0)
        // Simulate exploration with varying coherence
        var rates: Set<Double> = []
        for t in stride(from: 3.0, through: 60.0, by: 3.0) {
            pacer.update(coherence: Double.random(in: 0.2...0.8), elapsedTime: t)
            rates.insert(pacer.currentParameters.breathsPerMinute)
        }
        // Should have explored multiple rates
        XCTAssertGreaterThan(rates.count, 3, "Exploration should try multiple rates")
    }

    func testResonanceLockStabilizesAtBestRate() {
        let pacer = AdaptivePacer(calibrationDuration: 2.0, explorationDuration: 10.0)
        // Calibration
        pacer.update(coherence: 0.3, elapsedTime: 1.0)
        // Exploration - report high coherence at 6.0 bpm
        pacer.update(coherence: 0.9, elapsedTime: 5.0)
        let bestRate = pacer.currentParameters.breathsPerMinute
        // Push into resonance lock
        pacer.update(coherence: 0.85, elapsedTime: 13.0)
        XCTAssertEqual(pacer.sessionPhase, .resonanceLock)
        // Rate should be near the best observed rate
        XCTAssertEqual(pacer.currentParameters.breathsPerMinute, bestRate, accuracy: 0.5)
    }

    func testRateStaysWithinValidRange() {
        let pacer = AdaptivePacer(calibrationDuration: 1.0, explorationDuration: 5.0)
        for t in stride(from: 0.0, through: 100.0, by: 1.0) {
            pacer.update(coherence: Double.random(in: 0...1), elapsedTime: t)
            let bpm = pacer.currentParameters.breathsPerMinute
            XCTAssertGreaterThanOrEqual(bpm, BreathingParameters.minBPM)
            XCTAssertLessThanOrEqual(bpm, BreathingParameters.maxBPM)
        }
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Packages/BreathingCore && swift test --filter AdaptivePacerTests`
Expected: FAIL — AdaptivePacer not found

**Step 3: Implement AdaptivePacer — [HUMAN CONTRIBUTION]**

This is the core algorithm of the app. The pacer manages three phases: calibration (baseline), exploration (sweep rates), and resonance lock (fine-tune). See `TODO(human)` marker in the file.

```swift
// Packages/BreathingCore/Sources/BreathingCore/AdaptivePacer.swift
import Foundation

public final class AdaptivePacer: @unchecked Sendable {
    public enum SessionPhase: String, Sendable {
        case calibration
        case exploration
        case resonanceLock
    }

    private let calibrationDuration: Double
    private let explorationDuration: Double
    private let stepSize: Double = 0.1 // BPM adjustment per step

    public private(set) var sessionPhase: SessionPhase = .calibration
    public private(set) var currentParameters: BreathingParameters

    // Tracking
    private var coherenceHistory: [(time: Double, coherence: Double, bpm: Double)] = []
    private var bestCoherence: Double = 0.0
    private var bestBPM: Double = BreathingParameters.defaultBPM
    private var explorationDirection: Double = 1.0 // +1 or -1
    private var lastAdjustmentTime: Double = 0.0

    public init(
        calibrationDuration: Double = 120.0,
        explorationDuration: Double = 180.0,
        startingBPM: Double = BreathingParameters.defaultBPM
    ) {
        self.calibrationDuration = calibrationDuration
        self.explorationDuration = explorationDuration
        self.currentParameters = BreathingParameters(breathsPerMinute: startingBPM)
    }

    // TODO(human): Implement the update method.
    // This is the brain of the adaptive pacer. It receives a coherence score
    // and elapsed time, and must:
    // 1. Determine which session phase we're in based on elapsed time
    // 2. In calibration: just record baseline data, don't change rate
    // 3. In exploration: sweep through different rates to find peak coherence
    // 4. In resonance lock: stay near the best rate, make micro-adjustments
    //
    // Use self.coherenceHistory, self.bestCoherence, self.bestBPM,
    // self.explorationDirection, self.stepSize, and self.currentParameters
    public func update(coherence: Double, elapsedTime: Double) {
        // Record history
        coherenceHistory.append((time: elapsedTime, coherence: coherence, bpm: currentParameters.breathsPerMinute))

        // Track best
        if coherence > bestCoherence {
            bestCoherence = coherence
            bestBPM = currentParameters.breathsPerMinute
        }

        // Phase transitions
        if elapsedTime <= calibrationDuration {
            sessionPhase = .calibration
        } else if elapsedTime <= calibrationDuration + explorationDuration {
            sessionPhase = .exploration
            // YOUR CODE HERE — exploration logic
        } else {
            sessionPhase = .resonanceLock
            // YOUR CODE HERE — resonance lock logic
        }
    }
}
```

**Step 4: Run tests to verify partial pass (phase transitions work, exploration/lock logic pending)**

Run: `cd Packages/BreathingCore && swift test --filter AdaptivePacerTests`
Expected: Some tests pass (phase transitions), some fail (exploration sweep, resonance lock)

**Step 5: Human implements the exploration and resonance lock logic (see Learn by Doing prompt)**

**Step 6: Run tests to verify all pass**

Run: `cd Packages/BreathingCore && swift test --filter AdaptivePacerTests`
Expected: All tests pass

**Step 7: Commit**

```bash
git add Packages/BreathingCore/Sources/BreathingCore/AdaptivePacer.swift \
       Packages/BreathingCore/Tests/BreathingCoreTests/AdaptivePacerTests.swift
git commit -m "feat: add AdaptivePacer with 3-phase breathing rate optimization"
```

---

### Task 6: SwiftData Models

**Files:**
- Create: `ResonanceBreathing/Models/BreathingSession.swift`
- Create: `ResonanceBreathing/Models/SessionDataPoint.swift`
- Create: `ResonanceBreathing/Models/UserSettings.swift`

**Step 1: Create BreathingSession model**

```swift
// ResonanceBreathing/Models/BreathingSession.swift
import Foundation
import SwiftData

@Model
final class BreathingSession {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var averageHR: Double
    var averageRMSSD: Double
    var peakCoherence: Double
    var resonanceRate: Double
    @Relationship(deleteRule: .cascade) var dataPoints: [SessionDataPoint]

    init(
        date: Date = .now,
        duration: TimeInterval = 0,
        averageHR: Double = 0,
        averageRMSSD: Double = 0,
        peakCoherence: Double = 0,
        resonanceRate: Double = 0,
        dataPoints: [SessionDataPoint] = []
    ) {
        self.id = UUID()
        self.date = date
        self.duration = duration
        self.averageHR = averageHR
        self.averageRMSSD = averageRMSSD
        self.peakCoherence = peakCoherence
        self.resonanceRate = resonanceRate
        self.dataPoints = dataPoints
    }
}
```

**Step 2: Create SessionDataPoint model**

```swift
// ResonanceBreathing/Models/SessionDataPoint.swift
import Foundation
import SwiftData

@Model
final class SessionDataPoint {
    var timestamp: Date
    var hr: Double
    var rmssd: Double
    var coherence: Double
    var breathingRate: Double

    init(timestamp: Date = .now, hr: Double, rmssd: Double, coherence: Double, breathingRate: Double) {
        self.timestamp = timestamp
        self.hr = hr
        self.rmssd = rmssd
        self.coherence = coherence
        self.breathingRate = breathingRate
    }
}
```

**Step 3: Create UserSettings model**

```swift
// ResonanceBreathing/Models/UserSettings.swift
import Foundation
import SwiftData

@Model
final class UserSettings {
    var defaultDuration: TimeInterval
    var defaultBreathingRate: Double
    var hapticsEnabled: Bool
    var hapticIntensity: Double

    init(
        defaultDuration: TimeInterval = 600, // 10 minutes
        defaultBreathingRate: Double = 5.5,
        hapticsEnabled: Bool = true,
        hapticIntensity: Double = 0.8
    ) {
        self.defaultDuration = defaultDuration
        self.defaultBreathingRate = defaultBreathingRate
        self.hapticsEnabled = hapticsEnabled
        self.hapticIntensity = hapticIntensity
    }
}
```

**Step 4: Wire SwiftData into the app**

Update `ResonanceBreathingApp.swift`:

```swift
// ResonanceBreathing/ResonanceBreathingApp.swift
import SwiftUI
import SwiftData

@main
struct ResonanceBreathingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [BreathingSession.self, UserSettings.self])
    }
}

struct ContentView: View {
    var body: some View {
        Text("Resonance Breathing")
            .font(.title)
    }
}
```

**Step 5: Verify iOS target builds**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add ResonanceBreathing/Models/ ResonanceBreathing/ResonanceBreathingApp.swift
git commit -m "feat: add SwiftData models for sessions, data points, and settings"
```

---

### Task 7: App Theme & Color Constants

**Files:**
- Create: `ResonanceBreathing/Theme/AppTheme.swift`

**Step 1: Create the theme file**

```swift
// ResonanceBreathing/Theme/AppTheme.swift
import SwiftUI

enum AppTheme {
    // Background
    static let background = Color(red: 0.04, green: 0.055, blue: 0.1)  // #0A0E1A

    // Petals
    static let petalBlue = Color(red: 0.29, green: 0.565, blue: 0.85)  // #4A90D9
    static let petalTeal = Color(red: 0.176, green: 0.832, blue: 0.749) // #2DD4BF

    // Glow
    static let coherenceGlow = Color(red: 1.0, green: 0.95, blue: 0.8)  // Warm white/gold

    // Text
    static let primaryText = Color(red: 0.878, green: 0.906, blue: 1.0)  // #E0E7FF
    static let secondaryText = Color(red: 0.6, green: 0.65, blue: 0.75)

    // Chart
    static let chartLine = Color(red: 0.176, green: 0.832, blue: 0.749) // Teal

    // Coherence indicator
    static let coherenceActive = Color(red: 0.176, green: 0.832, blue: 0.749)
    static let coherenceInactive = Color(red: 0.3, green: 0.35, blue: 0.4)

    // Gradients
    static let petalGradient = LinearGradient(
        colors: [petalBlue, petalTeal],
        startPoint: .top,
        endPoint: .bottom
    )
}
```

**Step 2: Verify build**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ResonanceBreathing/Theme/AppTheme.swift
git commit -m "feat: add AppTheme with color palette and gradients"
```

---

### Task 8: Petal Shape & Bloom Animation

**Files:**
- Create: `ResonanceBreathing/Components/PetalShape.swift`
- Create: `ResonanceBreathing/Components/BloomAnimationView.swift`

**Step 1: Create the PetalShape**

```swift
// ResonanceBreathing/Components/PetalShape.swift
import SwiftUI

struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // Elliptical petal pointing upward
        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: width / 2, y: height),
            control: CGPoint(x: width, y: height * 0.4)
        )
        path.addQuadCurve(
            to: CGPoint(x: width / 2, y: 0),
            control: CGPoint(x: 0, y: height * 0.4)
        )
        return path
    }
}
```

**Step 2: Create the BloomAnimationView — [HUMAN CONTRIBUTION]**

The bloom animation is the visual heart of the app. The structure with petals and phase-driven animation is set up, with a `TODO(human)` for the core animation modifier.

```swift
// ResonanceBreathing/Components/BloomAnimationView.swift
import SwiftUI
import BreathingCore

struct BloomAnimationView: View {
    let phase: BreathingPhase
    let progress: Double       // 0.0–1.0 progress through current phase
    let coherence: Double      // 0.0–1.0 coherence score
    let petalCount: Int

    init(phase: BreathingPhase, progress: Double, coherence: Double, petalCount: Int = 7) {
        self.phase = phase
        self.progress = progress
        self.coherence = coherence
        self.petalCount = petalCount
    }

    var body: some View {
        ZStack {
            ForEach(0..<petalCount, id: \.self) { index in
                PetalShape()
                    .fill(petalFill)
                    .frame(width: 40, height: petalHeight)
                    .offset(y: -petalOffset)
                    .rotationEffect(.degrees(Double(index) * (360.0 / Double(petalCount))))
                    .shadow(color: glowColor, radius: glowRadius)
            }

            // Center circle
            Circle()
                .fill(AppTheme.petalTeal.opacity(0.6 + coherence * 0.4))
                .frame(width: 20, height: 20)
                .shadow(color: glowColor, radius: glowRadius * 0.5)
        }
        // TODO(human): Add animation modifier here.
        // The bloom should animate smoothly between phases using SwiftUI's
        // .animation() modifier. Consider which Animation curve feels most
        // natural for breathing — .easeInOut, .spring, or a custom
        // timingCurve. The animation should respond to changes in `expansion`.
        //
        // Hint: .animation(.easeInOut(duration: X), value: Y)
        // where X controls smoothness and Y is the value to animate on.
    }

    // MARK: - Computed properties

    /// 0.0 = fully contracted, 1.0 = fully expanded
    private var expansion: Double {
        switch phase {
        case .inhale: return progress
        case .hold: return 1.0
        case .exhale: return 1.0 - progress
        }
    }

    private var petalHeight: CGFloat {
        let minHeight: CGFloat = 30
        let maxHeight: CGFloat = 100
        return minHeight + CGFloat(expansion) * (maxHeight - minHeight)
    }

    private var petalOffset: CGFloat {
        petalHeight * 0.3
    }

    private var petalFill: some ShapeStyle {
        AppTheme.petalGradient.opacity(0.5 + expansion * 0.5)
    }

    private var glowColor: Color {
        AppTheme.coherenceGlow.opacity(coherence * 0.6)
    }

    private var glowRadius: CGFloat {
        CGFloat(coherence * 15 + expansion * 10)
    }
}

#Preview {
    BloomAnimationView(phase: .inhale, progress: 0.5, coherence: 0.8)
        .frame(width: 300, height: 300)
        .background(AppTheme.background)
}
```

**Step 3: Human adds the animation modifier (see Learn by Doing prompt)**

**Step 4: Verify build + preview renders**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add ResonanceBreathing/Components/PetalShape.swift \
       ResonanceBreathing/Components/BloomAnimationView.swift
git commit -m "feat: add petal bloom animation with phase-driven expansion and coherence glow"
```

---

### Task 9: Metrics Bar & Coherence Dots

**Files:**
- Create: `ResonanceBreathing/Components/MetricsBarView.swift`
- Create: `ResonanceBreathing/Components/CoherenceDotsView.swift`

**Step 1: Create CoherenceDotsView**

```swift
// ResonanceBreathing/Components/CoherenceDotsView.swift
import SwiftUI

struct CoherenceDotsView: View {
    let score: Double // 0.0–1.0
    private let totalDots = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalDots, id: \.self) { index in
                Circle()
                    .fill(index < activeDots ? AppTheme.coherenceActive : AppTheme.coherenceInactive)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var activeDots: Int {
        Int(round(score * Double(totalDots)))
    }
}
```

**Step 2: Create MetricsBarView**

```swift
// ResonanceBreathing/Components/MetricsBarView.swift
import SwiftUI

struct MetricsBarView: View {
    let heartRate: Double
    let rmssd: Double
    let coherence: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label("\(Int(heartRate)) bpm", systemImage: "heart.fill")
                    .foregroundStyle(.red.opacity(0.8))
                Spacer()
                Text("RMSSD: \(Int(rmssd))ms")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .font(.system(.caption, design: .monospaced))

            HStack {
                Text("Coherence:")
                    .foregroundStyle(AppTheme.secondaryText)
                CoherenceDotsView(score: coherence)
                Text("(\(Int(coherence * 100))%)")
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
            }
            .font(.system(.caption, design: .monospaced))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    MetricsBarView(heartRate: 68, rmssd: 42, coherence: 0.8)
        .background(AppTheme.background)
}
```

**Step 3: Verify build**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ResonanceBreathing/Components/MetricsBarView.swift \
       ResonanceBreathing/Components/CoherenceDotsView.swift
git commit -m "feat: add metrics bar and coherence dots indicator components"
```

---

### Task 10: HRV Waveform Chart

**Files:**
- Create: `ResonanceBreathing/Components/HRVChartView.swift`

**Step 1: Create HRVChartView using Swift Charts**

```swift
// ResonanceBreathing/Components/HRVChartView.swift
import SwiftUI
import Charts

struct HRVDataPoint: Identifiable {
    let id = UUID()
    let time: Double  // seconds from session start
    let value: Double // RMSSD in ms
}

struct HRVChartView: View {
    let dataPoints: [HRVDataPoint]
    let breathingRate: Double
    let isAdapting: Bool

    var body: some View {
        VStack(spacing: 4) {
            Chart(dataPoints) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("RMSSD", point.value)
                )
                .foregroundStyle(AppTheme.chartLine)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", point.time),
                    y: .value("RMSSD", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.chartLine.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .frame(height: 80)

            HStack {
                Text("Rate: \(String(format: "%.1f", breathingRate)) bpm")
                    .foregroundStyle(AppTheme.primaryText)
                if isAdapting {
                    Text("adapting")
                        .foregroundStyle(AppTheme.petalTeal)
                } else {
                    Text("locked")
                        .foregroundStyle(.green.opacity(0.8))
                }
                Spacer()
            }
            .font(.system(.caption2, design: .monospaced))
        }
        .padding(.horizontal)
    }
}

#Preview {
    let sampleData = (0..<60).map { i in
        HRVDataPoint(time: Double(i), value: 40 + sin(Double(i) * 0.3) * 10 + Double.random(in: -3...3))
    }
    HRVChartView(dataPoints: sampleData, breathingRate: 5.5, isAdapting: true)
        .background(AppTheme.background)
}
```

**Step 2: Verify build**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ResonanceBreathing/Components/HRVChartView.swift
git commit -m "feat: add real-time HRV waveform chart with Swift Charts"
```

---

### Task 11: BreathingTimer Service

**Files:**
- Create: `ResonanceBreathing/Services/BreathingTimer.swift`

**Step 1: Create BreathingTimer**

Drives the breathing animation by tracking current phase and progress within each phase.

```swift
// ResonanceBreathing/Services/BreathingTimer.swift
import Foundation
import BreathingCore
import Combine

@MainActor
final class BreathingTimer: ObservableObject {
    @Published var currentPhase: BreathingPhase = .inhale
    @Published var phaseProgress: Double = 0.0 // 0.0–1.0
    @Published var phaseTimeRemaining: Double = 0.0
    @Published var isRunning: Bool = false

    var parameters: BreathingParameters {
        didSet { updatePhaseDuration() }
    }

    private var displayLink: CADisplayLink?
    private var phaseStartTime: CFTimeInterval = 0
    private var currentPhaseDuration: Double = 0

    init(parameters: BreathingParameters = BreathingParameters(breathsPerMinute: 5.5)) {
        self.parameters = parameters
        updatePhaseDuration()
    }

    func start() {
        isRunning = true
        currentPhase = .inhale
        phaseProgress = 0
        updatePhaseDuration()
        phaseStartTime = CACurrentMediaTime()

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - phaseStartTime
        phaseProgress = min(elapsed / currentPhaseDuration, 1.0)
        phaseTimeRemaining = max(currentPhaseDuration - elapsed, 0)

        if elapsed >= currentPhaseDuration {
            advancePhase()
        }
    }

    private func advancePhase() {
        currentPhase = currentPhase.next
        phaseStartTime = CACurrentMediaTime()
        updatePhaseDuration()
    }

    private func updatePhaseDuration() {
        switch currentPhase {
        case .inhale: currentPhaseDuration = parameters.inhaleDuration
        case .hold: currentPhaseDuration = parameters.holdDuration
        case .exhale: currentPhaseDuration = parameters.exhaleDuration
        }
    }
}
```

**Step 2: Verify build**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ResonanceBreathing/Services/BreathingTimer.swift
git commit -m "feat: add BreathingTimer service with CADisplayLink-driven phase progression"
```

---

### Task 12: Session View (Main Breathing Screen)

**Files:**
- Create: `ResonanceBreathing/Views/SessionView.swift`

**Step 1: Create SessionView composing all components**

```swift
// ResonanceBreathing/Views/SessionView.swift
import SwiftUI
import BreathingCore

struct SessionView: View {
    @StateObject private var timer = BreathingTimer()
    @State private var heartRate: Double = 0
    @State private var rmssd: Double = 0
    @State private var coherence: Double = 0
    @State private var hrvData: [HRVDataPoint] = []
    @State private var isAdapting = true
    @State private var elapsedTime: TimeInterval = 0

    let onEnd: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top: Metrics bar
                MetricsBarView(heartRate: heartRate, rmssd: rmssd, coherence: coherence)
                    .padding(.top, 8)

                Spacer()

                // Center: Bloom animation
                BloomAnimationView(
                    phase: timer.currentPhase,
                    progress: timer.phaseProgress,
                    coherence: coherence
                )
                .frame(width: 250, height: 250)

                // Phase label
                VStack(spacing: 4) {
                    Text(timer.currentPhase.label)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(String(format: "%.1fs", timer.phaseTimeRemaining))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.top, 16)

                Spacer()

                // Bottom: HRV chart
                HRVChartView(
                    dataPoints: hrvData,
                    breathingRate: timer.parameters.breathsPerMinute,
                    isAdapting: isAdapting
                )
                .padding(.bottom, 16)
            }

            // End session button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        timer.stop()
                        onEnd()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear { timer.start() }
        .onDisappear { timer.stop() }
    }
}
```

**Step 2: Verify build**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ResonanceBreathing/Views/SessionView.swift
git commit -m "feat: add SessionView composing bloom, metrics, and HRV chart"
```

---

### Task 13: Home, Summary, History & Settings Views

**Files:**
- Create: `ResonanceBreathing/Views/HomeView.swift`
- Create: `ResonanceBreathing/Views/SummaryView.swift`
- Create: `ResonanceBreathing/Views/HistoryView.swift`
- Create: `ResonanceBreathing/Views/SettingsView.swift`
- Modify: `ResonanceBreathing/ResonanceBreathingApp.swift`

**Step 1: Create HomeView**

```swift
// ResonanceBreathing/Views/HomeView.swift
import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BreathingSession.date, order: .reverse) private var sessions: [BreathingSession]
    @State private var showSession = false
    @State private var completedSession: BreathingSession?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Title
                    Text("Resonance")
                        .font(.system(.largeTitle, design: .rounded, weight: .thin))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Breathing")
                        .font(.system(.title2, design: .rounded, weight: .light))
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    // Begin Session button
                    Button(action: { showSession = true }) {
                        Text("Begin Session")
                            .font(.system(.title3, design: .rounded, weight: .medium))
                            .foregroundStyle(AppTheme.background)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(AppTheme.petalTeal, in: Capsule())
                    }

                    // Last session card
                    if let last = sessions.first {
                        lastSessionCard(last)
                    }

                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: HistoryView()) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            .fullScreenCover(isPresented: $showSession) {
                SessionView(onEnd: {
                    showSession = false
                })
            }
            .sheet(item: $completedSession) { session in
                SummaryView(session: session)
            }
        }
    }

    private func lastSessionCard(_ session: BreathingSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Session")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            HStack {
                VStack(alignment: .leading) {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                    Text("\(Int(session.duration / 60)) min")
                        .font(.system(.body, design: .monospaced))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(String(format: "%.1f bpm", session.resonanceRate))
                        .font(.system(.body, design: .monospaced))
                    Text("\(Int(session.peakCoherence * 100))% peak")
                        .font(.caption2)
                }
            }
            .foregroundStyle(AppTheme.primaryText)
        }
        .padding()
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
```

**Step 2: Create SummaryView**

```swift
// ResonanceBreathing/Views/SummaryView.swift
import SwiftUI
import SwiftData

struct SummaryView: View {
    let session: BreathingSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Session Complete")
                    .font(.system(.title, design: .rounded, weight: .light))
                    .foregroundStyle(AppTheme.primaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statCard(title: "Duration", value: "\(Int(session.duration / 60)) min")
                    statCard(title: "Avg HR", value: "\(Int(session.averageHR)) bpm")
                    statCard(title: "Avg RMSSD", value: "\(Int(session.averageRMSSD)) ms")
                    statCard(title: "Peak Coherence", value: "\(Int(session.peakCoherence * 100))%")
                    statCard(title: "Resonance Rate", value: String(format: "%.1f bpm", session.resonanceRate))
                }
                .padding()

                Spacer()

                Button("Done") { dismiss() }
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(AppTheme.petalTeal)
                    .padding()
            }
            .padding()
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
```

**Step 3: Create HistoryView**

```swift
// ResonanceBreathing/Views/HistoryView.swift
import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Query(sort: \BreathingSession.date, order: .reverse) private var sessions: [BreathingSession]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if sessions.isEmpty {
                Text("No sessions yet")
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                List {
                    Section("Trends") {
                        trendChart
                            .listRowBackground(Color.white.opacity(0.05))
                    }

                    Section("Sessions") {
                        ForEach(sessions) { session in
                            sessionRow(session)
                                .listRowBackground(Color.white.opacity(0.05))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("History")
    }

    private var trendChart: some View {
        Chart(sessions.prefix(30).reversed()) { session in
            LineMark(
                x: .value("Date", session.date),
                y: .value("RMSSD", session.averageRMSSD)
            )
            .foregroundStyle(AppTheme.chartLine)
        }
        .frame(height: 120)
    }

    private func sessionRow(_ session: BreathingSession) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)
                Text("\(Int(session.duration / 60)) min")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(String(format: "%.1f bpm", session.resonanceRate))
                    .font(.system(.body, design: .monospaced))
                Text("\(Int(session.peakCoherence * 100))%")
                    .font(.caption)
                    .foregroundStyle(AppTheme.petalTeal)
            }
        }
        .foregroundStyle(AppTheme.primaryText)
    }
}
```

**Step 4: Create SettingsView**

```swift
// ResonanceBreathing/Views/SettingsView.swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var allSettings: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    private var settings: UserSettings {
        if let existing = allSettings.first { return existing }
        let new = UserSettings()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Form {
                Section("Session Defaults") {
                    Picker("Duration", selection: Binding(
                        get: { settings.defaultDuration },
                        set: { settings.defaultDuration = $0 }
                    )) {
                        Text("5 min").tag(TimeInterval(300))
                        Text("10 min").tag(TimeInterval(600))
                        Text("15 min").tag(TimeInterval(900))
                        Text("20 min").tag(TimeInterval(1200))
                    }

                    HStack {
                        Text("Starting Rate")
                        Spacer()
                        Text(String(format: "%.1f bpm", settings.defaultBreathingRate))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Slider(
                        value: Binding(
                            get: { settings.defaultBreathingRate },
                            set: { settings.defaultBreathingRate = $0 }
                        ),
                        in: 4.5...7.0,
                        step: 0.1
                    )
                }

                Section("Haptics") {
                    Toggle("Haptic Feedback", isOn: Binding(
                        get: { settings.hapticsEnabled },
                        set: { settings.hapticsEnabled = $0 }
                    ))
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
    }
}
```

**Step 5: Update app entry point to use HomeView**

```swift
// ResonanceBreathing/ResonanceBreathingApp.swift
import SwiftUI
import SwiftData

@main
struct ResonanceBreathingApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [BreathingSession.self, UserSettings.self])
    }
}
```

**Step 6: Verify build**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add ResonanceBreathing/Views/ ResonanceBreathing/ResonanceBreathingApp.swift
git commit -m "feat: add Home, Summary, History, and Settings views with SwiftData integration"
```

---

### Task 14: WatchConnectivity — Phone Side

**Files:**
- Create: `ResonanceBreathing/Services/WatchConnector.swift`

**Step 1: Create WatchConnector for the iPhone**

```swift
// ResonanceBreathing/Services/WatchConnector.swift
import Foundation
import WatchConnectivity
import BreathingCore

@MainActor
final class WatchConnector: NSObject, ObservableObject {
    @Published var isWatchReachable = false
    @Published var latestHeartRate: Double = 0
    @Published var latestRRIntervals: [Double] = []

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session
        }
    }

    /// Send breathing parameters to the watch for haptic timing.
    func sendBreathingParameters(_ params: BreathingParameters) {
        guard let session, session.isReachable else { return }
        let message: [String: Any] = [
            "type": "breathingParams",
            "inhaleDuration": params.inhaleDuration,
            "holdDuration": params.holdDuration,
            "exhaleDuration": params.exhaleDuration,
            "bpm": params.breathsPerMinute
        ]
        session.sendMessage(message, replyHandler: nil)
    }

    /// Tell the watch to start/stop the workout session.
    func sendCommand(_ command: String) {
        guard let session, session.isReachable else { return }
        session.sendMessage(["type": "command", "command": command], replyHandler: nil)
    }
}

extension WatchConnector: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }

    /// Receive HR and R-R data from the watch.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        Task { @MainActor in
            switch type {
            case "heartRateData":
                if let hr = message["hr"] as? Double {
                    latestHeartRate = hr
                }
                if let rr = message["rrIntervals"] as? [Double] {
                    latestRRIntervals = rr
                }
            default:
                break
            }
        }
    }
}
```

**Step 2: Verify build**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ResonanceBreathing/Services/WatchConnector.swift
git commit -m "feat: add WatchConnector for bidirectional phone-watch communication"
```

---

### Task 15: SessionManager — Orchestration Service

**Files:**
- Create: `ResonanceBreathing/Services/SessionManager.swift`

**Step 1: Create SessionManager that wires everything together**

```swift
// ResonanceBreathing/Services/SessionManager.swift
import Foundation
import SwiftData
import BreathingCore

@MainActor
final class SessionManager: ObservableObject {
    @Published var isActive = false
    @Published var heartRate: Double = 0
    @Published var rmssd: Double = 0
    @Published var coherence: Double = 0
    @Published var hrvDataPoints: [HRVDataPoint] = []

    let timer: BreathingTimer
    let watchConnector: WatchConnector
    let pacer: AdaptivePacer
    let hrvAnalyzer: HRVAnalyzer
    let coherenceCalculator: CoherenceCalculator

    private var sessionStartTime: Date?
    private var hrSamples: [Double] = []
    private var elapsedSeconds: Double = 0
    private var updateTimer: Timer?

    init() {
        self.timer = BreathingTimer()
        self.watchConnector = WatchConnector()
        self.pacer = AdaptivePacer()
        self.hrvAnalyzer = HRVAnalyzer()
        self.coherenceCalculator = CoherenceCalculator()
    }

    func startSession() {
        isActive = true
        sessionStartTime = .now
        elapsedSeconds = 0
        hrvDataPoints = []
        hrSamples = []
        hrvAnalyzer.reset()

        timer.start()
        watchConnector.sendCommand("startWorkout")

        // Poll watch data every 250ms
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processWatchData()
            }
        }
    }

    func endSession(modelContext: ModelContext) -> BreathingSession {
        isActive = false
        timer.stop()
        watchConnector.sendCommand("stopWorkout")
        updateTimer?.invalidate()

        let duration = Date.now.timeIntervalSince(sessionStartTime ?? .now)
        let session = BreathingSession(
            date: sessionStartTime ?? .now,
            duration: duration,
            averageHR: hrSamples.isEmpty ? 0 : hrSamples.reduce(0, +) / Double(hrSamples.count),
            averageRMSSD: rmssd,
            peakCoherence: coherence,
            resonanceRate: pacer.currentParameters.breathsPerMinute
        )
        modelContext.insert(session)
        return session
    }

    private func processWatchData() {
        elapsedSeconds += 0.25

        // Read latest HR from watch
        let hr = watchConnector.latestHeartRate
        if hr > 0 {
            heartRate = hr
            hrSamples.append(hr)
        }

        // Process R-R intervals
        for rr in watchConnector.latestRRIntervals {
            hrvAnalyzer.addInterval(rr: rr, timestamp: elapsedSeconds)
        }

        // Compute RMSSD
        if let currentRMSSD = hrvAnalyzer.currentRMSSD(at: elapsedSeconds) {
            rmssd = currentRMSSD
        }

        // Compute coherence (need enough HR samples)
        if hrSamples.count >= 32 {
            let recentHR = Array(hrSamples.suffix(120)) // last 30 seconds at 4 Hz
            let breathingFreqHz = timer.parameters.breathsPerMinute / 60.0
            coherence = coherenceCalculator.computeCoherence(
                hrSamples: recentHR,
                sampleRateHz: 4.0,
                breathingFreqHz: breathingFreqHz
            )
        }

        // Update adaptive pacer
        pacer.update(coherence: coherence, elapsedTime: elapsedSeconds)
        timer.parameters = pacer.currentParameters

        // Send updated params to watch for haptics
        watchConnector.sendBreathingParameters(pacer.currentParameters)

        // Record data point every second
        if Int(elapsedSeconds * 4) % 4 == 0 {
            hrvDataPoints.append(HRVDataPoint(time: elapsedSeconds, value: rmssd))
            // Keep last 60 seconds
            if hrvDataPoints.count > 60 {
                hrvDataPoints.removeFirst()
            }
        }
    }
}
```

**Step 2: Verify build**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ResonanceBreathing/Services/SessionManager.swift
git commit -m "feat: add SessionManager orchestrating timer, HRV, pacer, and watch connection"
```

---

### Task 16: watchOS — Workout Manager & HR Streaming

**Files:**
- Create: `ResonanceBreathingWatch Watch App/WorkoutManager.swift`
- Create: `ResonanceBreathingWatch Watch App/PhoneConnector.swift`

**Step 1: Create WorkoutManager**

```swift
// ResonanceBreathingWatch Watch App/WorkoutManager.swift
import Foundation
import HealthKit

class WorkoutManager: NSObject, ObservableObject {
    @Published var heartRate: Double = 0
    @Published var isWorkoutActive = false

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    var onHeartRateUpdate: ((Double, [Double]) -> Void)?

    func requestAuthorization() {
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        ]
        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { _, _ in }
    }

    func startWorkout() {
        let config = HKWorkoutConfiguration()
        config.activityType = .mindAndBody
        config.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = workoutSession?.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

            workoutSession?.delegate = self
            builder?.delegate = self

            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { _, _ in }
            isWorkoutActive = true
        } catch {
            print("Failed to start workout: \(error)")
        }
    }

    func stopWorkout() {
        workoutSession?.end()
        isWorkoutActive = false
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) else { continue }

            let statistics = workoutBuilder.statistics(for: quantityType)
            let hr = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0

            // Extract R-R intervals from heart beat series if available
            let rrIntervals: [Double] = [] // R-R extraction requires HKHeartbeatSeriesQuery (done in real implementation)

            DispatchQueue.main.async {
                self.heartRate = hr
                self.onHeartRateUpdate?(hr, rrIntervals)
            }
        }
    }
}
```

**Step 2: Create PhoneConnector (watch side of WatchConnectivity)**

```swift
// ResonanceBreathingWatch Watch App/PhoneConnector.swift
import Foundation
import WatchConnectivity

class PhoneConnector: NSObject, ObservableObject {
    @Published var inhaleDuration: Double = 4.36
    @Published var holdDuration: Double = 0.55
    @Published var exhaleDuration: Double = 6.0

    var onCommand: ((String) -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendHeartRateData(hr: Double, rrIntervals: [Double]) {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = [
            "type": "heartRateData",
            "hr": hr,
            "rrIntervals": rrIntervals
        ]
        WCSession.default.sendMessage(message, replyHandler: nil)
    }
}

extension PhoneConnector: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        DispatchQueue.main.async {
            switch type {
            case "breathingParams":
                self.inhaleDuration = message["inhaleDuration"] as? Double ?? self.inhaleDuration
                self.holdDuration = message["holdDuration"] as? Double ?? self.holdDuration
                self.exhaleDuration = message["exhaleDuration"] as? Double ?? self.exhaleDuration
            case "command":
                if let command = message["command"] as? String {
                    self.onCommand?(command)
                }
            default:
                break
            }
        }
    }
}
```

**Step 3: Verify watchOS target builds**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme "ResonanceBreathingWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -quiet`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add "ResonanceBreathingWatch Watch App/WorkoutManager.swift" \
       "ResonanceBreathingWatch Watch App/PhoneConnector.swift"
git commit -m "feat: add watchOS WorkoutManager and PhoneConnector for HR streaming"
```

---

### Task 17: watchOS — Haptic Engine

**Files:**
- Create: `ResonanceBreathingWatch Watch App/HapticEngine.swift`
- Modify: `ResonanceBreathingWatch Watch App/ResonanceBreathingWatchApp.swift`

**Step 1: Create HapticEngine with continuous patterns**

```swift
// ResonanceBreathingWatch Watch App/HapticEngine.swift
import Foundation
import WatchKit

final class HapticEngine: ObservableObject {
    @Published var currentPhase: String = "idle"

    private var hapticTimer: Timer?
    private var phaseStartTime: Date = .now
    private var inhaleDuration: Double = 4.36
    private var holdDuration: Double = 0.55
    private var exhaleDuration: Double = 6.0

    func updateParameters(inhale: Double, hold: Double, exhale: Double) {
        inhaleDuration = inhale
        holdDuration = hold
        exhaleDuration = exhale
    }

    func start() {
        phaseStartTime = .now
        currentPhase = "inhale"
        scheduleNextTick()
    }

    func stop() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        currentPhase = "idle"
    }

    private func scheduleNextTick() {
        let interval = currentHapticInterval()
        hapticTimer?.invalidate()
        hapticTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let elapsed = Date.now.timeIntervalSince(phaseStartTime)

        switch currentPhase {
        case "inhale":
            WKInterfaceDevice.current().play(.directionUp)
            if elapsed >= inhaleDuration {
                transitionTo("hold")
            } else {
                scheduleNextTick()
            }
        case "hold":
            WKInterfaceDevice.current().play(.click)
            if elapsed >= holdDuration {
                transitionTo("exhale")
            } else {
                scheduleNextTick()
            }
        case "exhale":
            WKInterfaceDevice.current().play(.directionDown)
            if elapsed >= exhaleDuration {
                transitionTo("inhale")
            } else {
                scheduleNextTick()
            }
        default:
            break
        }
    }

    private func transitionTo(_ phase: String) {
        currentPhase = phase
        phaseStartTime = .now
        // Brief silence between phases
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scheduleNextTick()
        }
    }

    /// Haptic interval accelerates during inhale, decelerates during exhale.
    private func currentHapticInterval() -> Double {
        let elapsed = Date.now.timeIntervalSince(phaseStartTime)

        switch currentPhase {
        case "inhale":
            // Accelerate: 0.8s → 0.3s over the inhale duration
            let progress = min(elapsed / inhaleDuration, 1.0)
            return 0.8 - progress * 0.5
        case "hold":
            return 0.6 // Steady
        case "exhale":
            // Decelerate: 0.3s → 0.8s over the exhale duration
            let progress = min(elapsed / exhaleDuration, 1.0)
            return 0.3 + progress * 0.5
        default:
            return 1.0
        }
    }
}
```

**Step 2: Update watchOS app to wire everything together**

```swift
// ResonanceBreathingWatch Watch App/ResonanceBreathingWatchApp.swift
import SwiftUI

@main
struct ResonanceBreathingWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var phoneConnector = PhoneConnector()
    @StateObject private var hapticEngine = HapticEngine()

    var body: some Scene {
        WindowGroup {
            WatchSessionView(
                workoutManager: workoutManager,
                phoneConnector: phoneConnector,
                hapticEngine: hapticEngine
            )
            .onAppear {
                workoutManager.requestAuthorization()
                workoutManager.onHeartRateUpdate = { hr, rr in
                    phoneConnector.sendHeartRateData(hr: hr, rrIntervals: rr)
                }
                phoneConnector.onCommand = { command in
                    switch command {
                    case "startWorkout":
                        workoutManager.startWorkout()
                        hapticEngine.start()
                    case "stopWorkout":
                        workoutManager.stopWorkout()
                        hapticEngine.stop()
                    default: break
                    }
                }
            }
        }
    }
}
```

**Step 3: Create WatchSessionView**

```swift
// ResonanceBreathingWatch Watch App/WatchSessionView.swift
import SwiftUI

struct WatchSessionView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var phoneConnector: PhoneConnector
    @ObservedObject var hapticEngine: HapticEngine

    var body: some View {
        VStack(spacing: 8) {
            if workoutManager.isWorkoutActive {
                Text(hapticEngine.currentPhase.uppercased())
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.teal)

                Text("\(Int(workoutManager.heartRate))")
                    .font(.system(size: 48, weight: .thin, design: .rounded))

                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Resonance")
                    .font(.headline)
                Text("Open iPhone app\nto begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
```

**Step 4: Verify watchOS builds**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme "ResonanceBreathingWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -quiet`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add "ResonanceBreathingWatch Watch App/"
git commit -m "feat: add watchOS haptic engine with accelerating/decelerating patterns and session view"
```

---

### Task 18: Integration — Wire SessionManager into SessionView

**Files:**
- Modify: `ResonanceBreathing/Views/SessionView.swift`

**Step 1: Refactor SessionView to use SessionManager**

Replace the placeholder `@State` properties with `@StateObject private var sessionManager = SessionManager()`, and bind all sub-views to `sessionManager`'s published properties.

```swift
// ResonanceBreathing/Views/SessionView.swift — updated
import SwiftUI
import SwiftData
import BreathingCore

struct SessionView: View {
    @StateObject private var sessionManager = SessionManager()
    @Environment(\.modelContext) private var modelContext
    let onEnd: (BreathingSession?) -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                MetricsBarView(
                    heartRate: sessionManager.heartRate,
                    rmssd: sessionManager.rmssd,
                    coherence: sessionManager.coherence
                )
                .padding(.top, 8)

                Spacer()

                BloomAnimationView(
                    phase: sessionManager.timer.currentPhase,
                    progress: sessionManager.timer.phaseProgress,
                    coherence: sessionManager.coherence
                )
                .frame(width: 250, height: 250)

                VStack(spacing: 4) {
                    Text(sessionManager.timer.currentPhase.label)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(String(format: "%.1fs", sessionManager.timer.phaseTimeRemaining))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.top, 16)

                Spacer()

                HRVChartView(
                    dataPoints: sessionManager.hrvDataPoints,
                    breathingRate: sessionManager.timer.parameters.breathsPerMinute,
                    isAdapting: sessionManager.pacer.sessionPhase != .resonanceLock
                )
                .padding(.bottom, 16)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: endSession) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear { sessionManager.startSession() }
        .onDisappear { if sessionManager.isActive { endSession() } }
    }

    private func endSession() {
        let session = sessionManager.endSession(modelContext: modelContext)
        onEnd(session)
    }
}
```

**Step 2: Update HomeView to handle session completion**

In `HomeView.swift`, update the `SessionView` call inside `.fullScreenCover`:

```swift
.fullScreenCover(isPresented: $showSession) {
    SessionView { session in
        showSession = false
        completedSession = session
    }
}
```

**Step 3: Verify build**

Run: `xcodegen generate && xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ResonanceBreathing/Views/SessionView.swift ResonanceBreathing/Views/HomeView.swift
git commit -m "feat: integrate SessionManager into SessionView and wire session completion flow"
```

---

### Task 19: End-to-End Smoke Test

**Step 1: Run all BreathingCore unit tests**

Run: `cd Packages/BreathingCore && swift test`
Expected: All tests pass

**Step 2: Build iOS target**

Run: `xcodebuild build -project ResonanceBreathing.xcodeproj -scheme ResonanceBreathing -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Build watchOS target**

Run: `xcodebuild build -project ResonanceBreathing.xcodeproj -scheme "ResonanceBreathingWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -quiet`
Expected: BUILD SUCCEEDED

**Step 4: Manual verification in Simulator**

- Open the iOS simulator
- Launch the app
- Verify Home screen renders with "Begin Session" button
- Tap Begin Session — verify bloom animation starts
- Verify phase label cycles: INHALE → HOLD → EXHALE
- Tap X to end session — verify Summary screen appears
- Navigate to History — verify session is listed
- Navigate to Settings — verify controls work

**Step 5: Final commit**

```bash
git add -A
git commit -m "chore: verify end-to-end build for iOS and watchOS targets"
```

---

## Summary

| Task | Description | Key Files | Test Method |
|------|------------|-----------|-------------|
| 1 | Project scaffolding | project.yml, Package.swift | Build both targets |
| 2 | BreathingPhase & Parameters | BreathingPhase.swift, BreathingParameters.swift | swift test |
| 3 | HRV Analyzer | HRVAnalyzer.swift | swift test |
| 4 | Coherence Calculator | CoherenceCalculator.swift | swift test |
| 5 | Adaptive Pacer (**human contrib**) | AdaptivePacer.swift | swift test |
| 6 | SwiftData models | BreathingSession/DataPoint/Settings | Build |
| 7 | App theme | AppTheme.swift | Build |
| 8 | Bloom animation (**human contrib**) | BloomAnimationView.swift, PetalShape.swift | Build + Preview |
| 9 | Metrics bar & coherence dots | MetricsBarView.swift, CoherenceDotsView.swift | Build |
| 10 | HRV chart | HRVChartView.swift | Build + Preview |
| 11 | Breathing timer | BreathingTimer.swift | Build |
| 12 | Session view | SessionView.swift | Build |
| 13 | Home/Summary/History/Settings | 4 view files | Build |
| 14 | WatchConnectivity (phone) | WatchConnector.swift | Build |
| 15 | Session manager | SessionManager.swift | Build |
| 16 | watchOS workout + HR streaming | WorkoutManager.swift, PhoneConnector.swift | Build |
| 17 | watchOS haptic engine | HapticEngine.swift, WatchSessionView.swift | Build |
| 18 | Integration wiring | SessionView.swift, HomeView.swift | Build |
| 19 | End-to-end smoke test | All files | Full test suite + simulator |

**Human contribution points:** Tasks 5 (adaptive pacer exploration/lock logic) and 8 (bloom animation modifier).
