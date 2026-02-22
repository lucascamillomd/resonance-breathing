import Foundation
import HealthKit
import BreathingCore

@MainActor
final class ECGPriorService {
    struct Prior: Sendable {
        let meanBPM: Double
        let stdBPM: Double
        let dataAge: TimeInterval
    }

    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        var readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        ]

        if #available(iOS 14.0, watchOS 7.0, *) {
            readTypes.insert(HKObjectType.electrocardiogramType())
        }

        readTypes.insert(HKSeriesType.heartbeat())

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func computePrior() async -> Prior? {
        guard let intervals = await fetchRecentHeartbeatIntervals() else { return nil }
        guard intervals.count >= 10 else { return nil }

        var timestamps: [Double] = [0]
        for rr in intervals {
            timestamps.append(timestamps.last! + rr / 1000.0)
        }

        let result = LombScargle.periodogram(
            timestamps: Array(timestamps.dropLast()),
            values: intervals.map { 60000.0 / $0 },
            minFreq: 0.04,
            maxFreq: 0.15,
            freqStep: 0.002
        )

        guard result.peakPower > 0 else { return nil }

        let resonantBPM = result.peakFrequency * 60.0
        guard resonantBPM >= 4.0 && resonantBPM <= 7.5 else { return nil }

        return Prior(
            meanBPM: resonantBPM,
            stdBPM: 0.3,
            dataAge: 0
        )
    }

    private func fetchRecentHeartbeatIntervals() async -> [Double]? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let heartbeatType = HKSeriesType.heartbeat()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let sampleQuery = HKSampleQuery(
                sampleType: heartbeatType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                guard let self,
                      let sample = samples?.first as? HKHeartbeatSeriesSample else {
                    continuation.resume(returning: nil)
                    return
                }

                var intervals: [Double] = []
                var previousTime: TimeInterval?

                let seriesQuery = HKHeartbeatSeriesQuery(heartbeatSeries: sample) { _, timeSinceStart, precededByGap, done, error in
                    if let prev = previousTime, !precededByGap {
                        let rrMs = (timeSinceStart - prev) * 1000.0
                        if rrMs > 300 && rrMs < 2000 {
                            intervals.append(rrMs)
                        }
                    }
                    previousTime = timeSinceStart

                    if done {
                        continuation.resume(returning: intervals.isEmpty ? nil : intervals)
                    }
                }
                self.healthStore.execute(seriesQuery)
            }
            healthStore.execute(sampleQuery)
        }
    }
}
