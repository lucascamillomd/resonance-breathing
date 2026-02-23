import Foundation
import HealthKit
import BreathingCore

class WorkoutManager: NSObject, ObservableObject {
    @Published var heartRate: Double = 0
    @Published var isWorkoutActive = false

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var sampleSequence = 0

    var onHeartRateUpdate: ((Double, [Double], TimeInterval, Int) -> Void)?

    func requestAuthorization() {
        #if targetEnvironment(simulator)
        // HealthKit authorization shows a blocking dialog in the simulator
        // that cannot be dismissed programmatically. Skip it.
        #else
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        ]
        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { _, _ in }
        #endif
    }

    func startWorkout() {
        guard !isWorkoutActive else { return }

        #if targetEnvironment(simulator)
        sampleSequence = 0
        isWorkoutActive = true
        #else
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .indoor
        sampleSequence = 0

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
        #endif
    }

    func stopWorkout() {
        guard isWorkoutActive else { return }
        #if !targetEnvironment(simulator)
        builder?.discardWorkout()
        workoutSession?.end()
        builder = nil
        workoutSession = nil
        #endif
        isWorkoutActive = false
    }

    private func pseudoRRIntervals(from heartRate: Double) -> [Double] {
        guard let rr = HeartMath.pseudoRRIntervalMillis(fromHeartRate: heartRate) else { return [] }
        return [rr]
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
            let rrIntervals = pseudoRRIntervals(from: hr)
            let timestamp = Date.now.timeIntervalSince1970
            sampleSequence += 1
            let sequence = sampleSequence

            DispatchQueue.main.async {
                self.heartRate = hr
                self.onHeartRateUpdate?(hr, rrIntervals, timestamp, sequence)
            }
        }
    }
}
