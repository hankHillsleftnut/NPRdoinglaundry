import Foundation
import HealthKit

struct DailyHealthSnapshot {
    let day: Date
    let steps: Int?
    let activeEnergyKcal: Int?
    let averageHeartRateBpm: Int?
    let sleepHours: Double?
    let mindfulnessMinutes: Int?
    let distanceKilometers: Double?
    let exerciseMinutes: Int?
    let restingHeartRateBpm: Int?
    let heartRateVariabilityMs: Int?
    let sleepStagesHours: [String: Double]
    let workoutCount: Int
    let workoutMinutes: Int
    let workoutTypes: [String: Int]
    let canonicalText: String

    var normalizedData: [String: Any] {
        var data: [String: Any] = [
            "metric_availability": [
                "steps": steps != nil,
                "active_energy_kcal": activeEnergyKcal != nil,
                "average_heart_rate_bpm": averageHeartRateBpm != nil,
                "sleep_hours": sleepHours != nil,
                "mindfulness_minutes": mindfulnessMinutes != nil,
                "distance_kilometers": distanceKilometers != nil,
                "exercise_minutes": exerciseMinutes != nil,
                "resting_heart_rate_bpm": restingHeartRateBpm != nil,
                "heart_rate_variability_ms": heartRateVariabilityMs != nil,
            ],
            "sleep_stages_hours": sleepStagesHours,
            "workout_count": workoutCount,
            "workout_minutes": workoutMinutes,
            "workout_types": workoutTypes,
        ]
        if let steps { data["steps"] = steps }
        if let activeEnergyKcal { data["active_energy_kcal"] = activeEnergyKcal }
        if let averageHeartRateBpm { data["average_heart_rate_bpm"] = averageHeartRateBpm }
        if let sleepHours { data["sleep_hours"] = sleepHours }
        if let mindfulnessMinutes { data["mindfulness_minutes"] = mindfulnessMinutes }
        if let distanceKilometers { data["distance_kilometers"] = distanceKilometers }
        if let exerciseMinutes { data["exercise_minutes"] = exerciseMinutes }
        if let restingHeartRateBpm { data["resting_heart_rate_bpm"] = restingHeartRateBpm }
        if let heartRateVariabilityMs { data["heart_rate_variability_ms"] = heartRateVariabilityMs }
        return data
    }
}

private struct WorkoutDaySummary {
    let count: Int
    let minutes: Int
    let activityTypes: [String: Int]
}

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private init() {}
    
    /// Request authorization to read health data
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        print("🏥 HealthKit: Starting authorization request...")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit: Health data not available on this device")
            completion(false)
            return
        }
        
        print("✅ HealthKit: Health data is available")
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
            HKObjectType.workoutType(),
        ]
        
        print("🔐 HealthKit: Requesting authorization for \(typesToRead.count) data types...")
        print("🔐 HealthKit: This should trigger the iOS permission dialog...")
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ HealthKit authorization error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ HealthKit: Authorization request completed. Success: \(success)")
                    print("ℹ️ HealthKit: Note - 'success' only means the dialog was shown, not that permission was granted")
                    // For read-only permissions, success=true just means the request was processed
                    // We return true to indicate the request completed (user saw the dialog)
                    self.enableBackgroundDelivery(for: typesToRead)
                    completion(true)
                }
            }
        }
    }

    private func enableBackgroundDelivery(for types: Set<HKObjectType>) {
        observerQueries.forEach { healthStore.stop($0) }
        observerQueries.removeAll()

        for objectType in types {
            guard let sampleType = objectType as? HKSampleType else { continue }
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { success, error in
                if !success, let error {
                    print("HealthKit background delivery could not be enabled: \(error.localizedDescription)")
                }
            }
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completion, error in
                defer { completion() }
                guard error == nil else { return }
                Task { @MainActor in
                    IntegrationsSyncService.shared.syncIfNeeded()
                }
            }
            observerQueries.append(query)
            healthStore.execute(query)
        }
    }
    
    /// Check if HealthKit is available on this device
    func isHealthDataAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    /// Note: For READ-only permissions, Apple intentionally hides authorization status
    /// for privacy reasons. We cannot reliably check if user granted read access.
    /// The app should just try to fetch data - if denied, values will be empty/zero.
    func hasHealthKitPermissions() -> Bool {
        // We can only check if HealthKit is available, not if user granted read access
        return HKHealthStore.isHealthDataAvailable()
    }
    
    func fetchWeeklyHealthData(completion: @escaping (String) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion("")
            return
        }
        
        // Note: We don't check permissions here because for READ-only access,
        // Apple doesn't reveal authorization status. We just try to fetch data
        // and if user denied access, the values will be zero/empty.
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        
        var healthSummary = "Health Summary for the Past Week:\n\n"
        
        let group = DispatchGroup()
        
        // Fetch steps
        group.enter()
        fetchSteps(startDate: startDate, endDate: now) { steps in
            healthSummary += "Steps: \(steps.map(String.init) ?? "Unavailable")\n"
            group.leave()
        }
        
        // Fetch active energy
        group.enter()
        fetchActiveEnergy(startDate: startDate, endDate: now) { energy in
            healthSummary += "Active Energy: \(energy.map { String(format: "%.0f", $0) } ?? "Unavailable") kcal\n"
            group.leave()
        }
        
        // Fetch average heart rate
        group.enter()
        fetchAverageHeartRate(startDate: startDate, endDate: now) { heartRate in
            healthSummary += "Average Heart Rate: \(heartRate.map { String(format: "%.0f", $0) } ?? "Unavailable") BPM\n"
            group.leave()
        }
        
        // Fetch sleep analysis
        group.enter()
        fetchSleepAnalysis(startDate: startDate, endDate: now) { sleepHours in
            healthSummary += "Average Sleep: \(sleepHours.map { String(format: "%.1f", $0) } ?? "Unavailable") hours\n"
            group.leave()
        }
        
        // Fetch mindfulness minutes
        group.enter()
        fetchMindfulnessMinutes(startDate: startDate, endDate: now) { minutes in
            healthSummary += "Mindfulness: \(minutes.map(String.init) ?? "Unavailable") minutes\n"
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(healthSummary)
        }
    }

    func fetchDailyHealthSummary(for day: Date) async -> String {
        await fetchDailyHealthSnapshot(for: day)?.canonicalText ?? ""
    }

    func fetchDailyHealthSnapshot(for day: Date) async -> DailyHealthSnapshot? {
        guard HKHealthStore.isHealthDataAvailable() else {
            return nil
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: day)
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else {
            return nil
        }

        async let steps = fetchSteps(startDate: startDate, endDate: endDate)
        async let activeEnergy = fetchActiveEnergy(startDate: startDate, endDate: endDate)
        async let averageHeartRate = fetchAverageHeartRate(startDate: startDate, endDate: endDate)
        // Sleep is counted over the night ending this morning, not from midnight.
        // See SleepMath for the three ways the old count went wrong.
        async let night = fetchNight(for: day)
        async let mindfulnessMinutes = fetchMindfulnessMinutes(startDate: startDate, endDate: endDate)
        async let distanceKilometers = fetchCumulativeQuantity(
            identifier: .distanceWalkingRunning,
            unit: .meterUnit(with: .kilo),
            startDate: startDate,
            endDate: endDate
        )
        async let exerciseMinutes = fetchCumulativeQuantity(
            identifier: .appleExerciseTime,
            unit: .minute(),
            startDate: startDate,
            endDate: endDate
        )
        async let restingHeartRate = fetchAverageQuantity(
            identifier: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            startDate: startDate,
            endDate: endDate
        )
        async let heartRateVariability = fetchAverageQuantity(
            identifier: .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            startDate: startDate,
            endDate: endDate
        )
        async let workouts = fetchWorkouts(startDate: startDate, endDate: endDate)

        let values = await (
            steps: steps,
            activeEnergy: activeEnergy,
            averageHeartRate: averageHeartRate,
            night: night,
            mindfulnessMinutes: mindfulnessMinutes,
            distanceKilometers: distanceKilometers,
            exerciseMinutes: exerciseMinutes,
            restingHeartRate: restingHeartRate,
            heartRateVariability: heartRateVariability,
            workouts: workouts
        )

        let roundedEnergy = values.activeEnergy.map { Int($0.rounded()) }
        let roundedHeartRate = values.averageHeartRate.map { Int($0.rounded()) }
        let sleep = values.night.hours.map { String(format: "%.1f", $0) } ?? "Unavailable"
        let workoutSummary = values.workouts ?? WorkoutDaySummary(count: 0, minutes: 0, activityTypes: [:])

        return DailyHealthSnapshot(
            day: startDate,
            steps: values.steps,
            activeEnergyKcal: roundedEnergy,
            averageHeartRateBpm: roundedHeartRate,
            sleepHours: values.night.hours,
            mindfulnessMinutes: values.mindfulnessMinutes,
            distanceKilometers: values.distanceKilometers,
            exerciseMinutes: values.exerciseMinutes.map { Int($0.rounded()) },
            restingHeartRateBpm: values.restingHeartRate.map { Int($0.rounded()) },
            heartRateVariabilityMs: values.heartRateVariability.map { Int($0.rounded()) },
            sleepStagesHours: values.night.stages,
            workoutCount: workoutSummary.count,
            workoutMinutes: workoutSummary.minutes,
            workoutTypes: workoutSummary.activityTypes,
            canonicalText: """
            Apple Health summary for \(displayDateFormatter.string(from: startDate)):

            Steps: \(values.steps.map(String.init) ?? "Unavailable")
            Active Energy: \(roundedEnergy.map(String.init) ?? "Unavailable") kcal
            Average Heart Rate: \(roundedHeartRate.map(String.init) ?? "Unavailable") BPM
            Sleep: \(sleep) hours
            Sleep stages: \(values.night.stages.map { "\($0.key) \(String(format: "%.1f", $0.value))h" }.sorted().joined(separator: ", "))
            Mindfulness: \(values.mindfulnessMinutes.map(String.init) ?? "Unavailable") minutes
            Walking and running distance: \(values.distanceKilometers.map { String(format: "%.1f", $0) } ?? "Unavailable") km
            Exercise: \(values.exerciseMinutes.map { String(format: "%.0f", $0) } ?? "Unavailable") minutes
            Resting heart rate: \(values.restingHeartRate.map { String(format: "%.0f", $0) } ?? "Unavailable") BPM
            Heart-rate variability: \(values.heartRateVariability.map { String(format: "%.0f", $0) } ?? "Unavailable") ms
            Workouts: \(workoutSummary.count), \(workoutSummary.minutes) minutes
            """
        )
    }

    private func fetchCumulativeQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func fetchAverageQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                continuation.resume(returning: result?.averageQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    /// One night's sleep: hours asleep (nil if nothing recorded sleep) and hours
    /// per stage, over the noon-to-noon window ending on `day`.
    private func fetchNight(for day: Date) async -> (hours: Double?, stages: [String: Double]) {
        guard
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let window = SleepMath.nightWindow(for: day)
        else { return (nil, [:]) }

        let samples: [SleepMath.Sample] = await withCheckedContinuation { continuation in
            // No .strictStartDate: a sample that began before the window still
            // counts for the part inside it. SleepMath clips it.
            let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: [])
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let mapped = (samples as? [HKCategorySample] ?? []).map {
                    SleepMath.Sample(start: $0.startDate, end: $0.endDate, stage: Self.sleepStageKey($0.value))
                }
                continuation.resume(returning: mapped)
            }
            healthStore.execute(query)
        }
        return (SleepMath.hoursAsleep(samples, in: window), SleepMath.stageHours(samples, in: window))
    }

    private static func sleepStageKey(_ value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.awake.rawValue: return "awake"
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue: return "core"
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: return "deep"
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue: return "rem"
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: return "asleep_unspecified"
        case HKCategoryValueSleepAnalysis.inBed.rawValue: return "in_bed"
        default: return "other"
        }
    }

    private func fetchWorkouts(startDate: Date, endDate: Date) async -> WorkoutDaySummary? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let workouts = samples as? [HKWorkout] ?? []
                guard !workouts.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                var types: [String: Int] = [:]
                for workout in workouts {
                    types[String(workout.workoutActivityType.rawValue), default: 0] += 1
                }
                continuation.resume(returning: WorkoutDaySummary(
                    count: workouts.count,
                    minutes: Int(workouts.reduce(0) { $0 + $1.duration } / 60),
                    activityTypes: types
                ))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchSteps(startDate: Date, endDate: Date) async -> Int? {
        await withCheckedContinuation { continuation in
            fetchSteps(startDate: startDate, endDate: endDate) { continuation.resume(returning: $0) }
        }
    }

    private func fetchSteps(startDate: Date, endDate: Date, completion: @escaping (Int?) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(nil)
                return
            }
            
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            completion(steps)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchActiveEnergy(startDate: Date, endDate: Date) async -> Double? {
        await withCheckedContinuation { continuation in
            fetchActiveEnergy(startDate: startDate, endDate: endDate) { continuation.resume(returning: $0) }
        }
    }

    private func fetchActiveEnergy(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(nil)
                return
            }
            
            let energy = sum.doubleValue(for: HKUnit.kilocalorie())
            completion(energy)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchAverageHeartRate(startDate: Date, endDate: Date) async -> Double? {
        await withCheckedContinuation { continuation in
            fetchAverageHeartRate(startDate: startDate, endDate: endDate) { continuation.resume(returning: $0) }
        }
    }

    private func fetchAverageHeartRate(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, result, error in
            guard let result = result, let average = result.averageQuantity() else {
                completion(nil)
                return
            }
            
            let heartRate = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            completion(heartRate)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchSleepAnalysis(startDate: Date, endDate: Date, averagingDays: Int) async -> Double? {
        await withCheckedContinuation { continuation in
            fetchSleepAnalysis(startDate: startDate, endDate: endDate, averagingDays: averagingDays) {
                continuation.resume(returning: $0)
            }
        }
    }

    private func fetchSleepAnalysis(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        fetchSleepAnalysis(startDate: startDate, endDate: endDate, averagingDays: 7, completion: completion)
    }

    private func fetchSleepAnalysis(
        startDate: Date,
        endDate: Date,
        averagingDays: Int,
        completion: @escaping (Double?) -> Void
    ) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                completion(nil)
                return
            }
            
            let totalSleepTime = samples.reduce(0.0) { total, sample in
                if Self.isAsleep(sample.value) {
                    return total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                return total
            }
            
            let averageSleepHours = totalSleepTime / (Double(max(averagingDays, 1)) * 3600)
            completion(averageSleepHours)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchMindfulnessMinutes(startDate: Date, endDate: Date) async -> Int? {
        await withCheckedContinuation { continuation in
            fetchMindfulnessMinutes(startDate: startDate, endDate: endDate) { continuation.resume(returning: $0) }
        }
    }

    private func fetchMindfulnessMinutes(startDate: Date, endDate: Date, completion: @escaping (Int?) -> Void) {
        guard let mindfulnessType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: mindfulnessType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                completion(nil)
                return
            }
            
            let totalMinutes = samples.reduce(0) { total, sample in
                return total + Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
            }
            
            completion(totalMinutes)
        }
        
        healthStore.execute(query)
    }

    private static func isAsleep(_ value: Int) -> Bool {
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        return asleepValues.contains(value)
    }
}
