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

            let rrIntervals: [Double] = []

            DispatchQueue.main.async {
                self.heartRate = hr
                self.onHeartRateUpdate?(hr, rrIntervals)
            }
        }
    }
}
