import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
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
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
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
                    completion(true)
                }
            }
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
            healthSummary += "Steps: \(steps)\n"
            group.leave()
        }
        
        // Fetch active energy
        group.enter()
        fetchActiveEnergy(startDate: startDate, endDate: now) { energy in
            healthSummary += "Active Energy: \(energy) kcal\n"
            group.leave()
        }
        
        // Fetch average heart rate
        group.enter()
        fetchAverageHeartRate(startDate: startDate, endDate: now) { heartRate in
            healthSummary += "Average Heart Rate: \(heartRate) BPM\n"
            group.leave()
        }
        
        // Fetch sleep analysis
        group.enter()
        fetchSleepAnalysis(startDate: startDate, endDate: now) { sleepHours in
            healthSummary += "Average Sleep: \(sleepHours) hours\n"
            group.leave()
        }
        
        // Fetch mindfulness minutes
        group.enter()
        fetchMindfulnessMinutes(startDate: startDate, endDate: now) { minutes in
            healthSummary += "Mindfulness: \(minutes) minutes\n"
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(healthSummary)
        }
    }

    func fetchDailyHealthSummary(for day: Date) async -> String {
        guard HKHealthStore.isHealthDataAvailable() else {
            return ""
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: day)
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else {
            return ""
        }

        async let steps = fetchSteps(startDate: startDate, endDate: endDate)
        async let activeEnergy = fetchActiveEnergy(startDate: startDate, endDate: endDate)
        async let averageHeartRate = fetchAverageHeartRate(startDate: startDate, endDate: endDate)
        async let sleepHours = fetchSleepAnalysis(startDate: startDate, endDate: endDate, averagingDays: 1)
        async let mindfulnessMinutes = fetchMindfulnessMinutes(startDate: startDate, endDate: endDate)

        let values = await (
            steps: steps,
            activeEnergy: activeEnergy,
            averageHeartRate: averageHeartRate,
            sleepHours: sleepHours,
            mindfulnessMinutes: mindfulnessMinutes
        )

        let roundedEnergy = Int(values.activeEnergy.rounded())
        let roundedHeartRate = Int(values.averageHeartRate.rounded())
        let sleep = String(format: "%.1f", values.sleepHours)

        return """
        Apple Health summary for \(displayDateFormatter.string(from: startDate)):

        Steps: \(values.steps)
        Active Energy: \(roundedEnergy) kcal
        Average Heart Rate: \(roundedHeartRate) BPM
        Sleep: \(sleep) hours
        Mindfulness: \(values.mindfulnessMinutes) minutes
        """
    }
    
    private func fetchSteps(startDate: Date, endDate: Date) async -> Int {
        await withCheckedContinuation { continuation in
            fetchSteps(startDate: startDate, endDate: endDate) { continuation.resume(returning: $0) }
        }
    }

    private func fetchSteps(startDate: Date, endDate: Date, completion: @escaping (Int) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0)
                return
            }
            
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            completion(steps)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchActiveEnergy(startDate: Date, endDate: Date) async -> Double {
        await withCheckedContinuation { continuation in
            fetchActiveEnergy(startDate: startDate, endDate: endDate) { continuation.resume(returning: $0) }
        }
    }

    private func fetchActiveEnergy(startDate: Date, endDate: Date, completion: @escaping (Double) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(0)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0)
                return
            }
            
            let energy = sum.doubleValue(for: HKUnit.kilocalorie())
            completion(energy)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchAverageHeartRate(startDate: Date, endDate: Date) async -> Double {
        await withCheckedContinuation { continuation in
            fetchAverageHeartRate(startDate: startDate, endDate: endDate) { continuation.resume(returning: $0) }
        }
    }

    private func fetchAverageHeartRate(startDate: Date, endDate: Date, completion: @escaping (Double) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(0)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, result, error in
            guard let result = result, let average = result.averageQuantity() else {
                completion(0)
                return
            }
            
            let heartRate = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            completion(heartRate)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchSleepAnalysis(startDate: Date, endDate: Date, averagingDays: Int) async -> Double {
        await withCheckedContinuation { continuation in
            fetchSleepAnalysis(startDate: startDate, endDate: endDate, averagingDays: averagingDays) {
                continuation.resume(returning: $0)
            }
        }
    }

    private func fetchSleepAnalysis(startDate: Date, endDate: Date, completion: @escaping (Double) -> Void) {
        fetchSleepAnalysis(startDate: startDate, endDate: endDate, averagingDays: 7, completion: completion)
    }

    private func fetchSleepAnalysis(
        startDate: Date,
        endDate: Date,
        averagingDays: Int,
        completion: @escaping (Double) -> Void
    ) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(0)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            guard let samples = samples as? [HKCategorySample] else {
                completion(0)
                return
            }
            
            let totalSleepTime = samples.reduce(0.0) { total, sample in
                if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                    return total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                return total
            }
            
            let averageSleepHours = totalSleepTime / (Double(max(averagingDays, 1)) * 3600)
            completion(averageSleepHours)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchMindfulnessMinutes(startDate: Date, endDate: Date) async -> Int {
        await withCheckedContinuation { continuation in
            fetchMindfulnessMinutes(startDate: startDate, endDate: endDate) { continuation.resume(returning: $0) }
        }
    }

    private func fetchMindfulnessMinutes(startDate: Date, endDate: Date, completion: @escaping (Int) -> Void) {
        guard let mindfulnessType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            completion(0)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: mindfulnessType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            guard let samples = samples as? [HKCategorySample] else {
                completion(0)
                return
            }
            
            let totalMinutes = samples.reduce(0) { total, sample in
                return total + Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
            }
            
            completion(totalMinutes)
        }
        
        healthStore.execute(query)
    }
}
