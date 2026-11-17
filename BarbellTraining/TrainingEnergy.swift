import SwiftUI
import HealthKit

private struct HealthWorkoutMatch: Identifiable {
    let id: UUID
    let start: Date
    let end: Date
    let calories: Double
}

enum TrainingEnergy {
    static func estimate(session: CompletedTraining, weight: Double, sets: [TrainingSet]) -> Double? {
        guard weight.isFinite, (20...500).contains(weight), session.endedAt > session.startedAt else { return nil }
        let recorded = sets.filter { $0.planID == session.id && $0.weight.isFinite && $0.weight >= 0 && $0.reps > 0 }
        guard !recorded.isEmpty else { return nil }
        // Approximate whole-session intensity using the Compendium's 3.5/5 MET categories.
        // The load adjustment is a bounded heuristic, not a validated calorie model.
        let estimatedMET = recorded.reduce(0.0) { total, set in
            let action = TrainingStore.actionKey(set.note ?? "")
            let base = (action == "深蹲" || action == "硬拉") ? 5.0 : 3.5
            let relativeLoad = min(2.0, max(0.25, set.weight / weight))
            let adjustment = 1 + (relativeLoad - 0.75) * 0.16
            return total + min(6.0, max(3.0, base * adjustment))
        } / Double(recorded.count)
        return (estimatedMET - 1) * weight * 3.5 / 200 * session.endedAt.timeIntervalSince(session.startedAt) / 60
    }

    static func description(session: CompletedTraining, weight: Double, sets: [TrainingSet]) -> String? {
        if let calories = session.healthCalories { return "\(Int(calories.rounded())) 千卡 · Apple 健康" }
        if let calories = estimate(session: session, weight: weight, sets: sets) { return "约 \(Int(calories.rounded())) 千卡 · 估算" }
        return nil
    }
}

struct TrainingEnergySection: View {
    @EnvironmentObject private var store: TrainingStore
    @AppStorage("energyBodyWeight") private var bodyWeight = ""
    @AppStorage("healthAccessRequested") private var requested = false
    @State private var matches: [HealthWorkoutMatch] = []
    @State private var choosing = false
    @State private var matchesSessionID: UUID?
    @State private var loading = false
    @State private var message: String?
    private let health = HKHealthStore()

    private var latest: CompletedTraining? { store.completedTrainings.max { $0.endedAt < $1.endedAt } }
    private var weight: Double { Double(bodyWeight.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    var body: some View {
        Section("最近一次训练消耗") {
            if let session = latest {
                Text("\(session.startedAt.formatted(date: .numeric, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
                if let text = TrainingEnergy.description(session: session, weight: weight, sets: store.sets) {
                    Text(text).font(.headline)
                } else {
                    Text("暂无热量数据，请读取 Apple 健康或填写体重以估算。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text("开始训练并结束后，可查看整次训练的消耗。旧记录没有完整训练时段。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Text("体重（kg）")
                TextField("用于估算", text: $bodyWeight).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            }
            Text("根据体重、本次训练的动作、重量和时长自动粗略估算；无法判断实际用力程度，休息较长时可能偏高。修改体重或训练记录会更新估算。")
                .font(.footnote).foregroundStyle(.secondary)
            Button(requested ? "重新读取 Apple 健康" : "连接 Apple 健康") { Task { await connectAndRead() } }
                .disabled(loading)
            if let message = message { Text(message).font(.footnote).foregroundStyle(.secondary) }
        }
        .confirmationDialog("选择对应的 Apple 健康训练", isPresented: $choosing, titleVisibility: .visible) {
            ForEach(matches) { match in
                Button("\(match.start.formatted(date: .numeric, time: .shortened)) – \(match.end.formatted(date: .omitted, time: .shortened)) · \(Int(match.calories.rounded())) 千卡") {
                    save(match)
                }
            }
            Button("取消", role: .cancel) {}
        } message: { Text("发现多条重叠的力量训练，请选择对应记录。") }
        .task(id: latest?.id) {
            if requested, latest?.healthWorkoutID == nil { await readMatches() }
        }
    }

    @MainActor private func connectAndRead() async {
        guard HKHealthStore.isHealthDataAvailable() else { message = "当前设备无法使用 Apple 健康。"; return }
        loading = true
        defer { loading = false }
        do {
            let active = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                health.requestAuthorization(toShare: [], read: [HKObjectType.workoutType(), active]) { _, error in
                    if let error = error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
            requested = true
            if latest == nil {
                message = "已发起 Apple 健康授权；完成一次训练后可读取对应的消耗数据。"
            } else {
                await readMatches()
            }
        } catch { message = "无法连接 Apple 健康：\(error.localizedDescription)" }
    }

    @MainActor private func readMatches() async {
        guard let session = latest, HKHealthStore.isHealthDataAvailable() else { return }
        loading = true
        defer { loading = false }
        let predicate = HKQuery.predicateForSamples(withStart: session.startedAt, end: session.endedAt, options: [])
        do {
            let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error = error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: samples as? [HKWorkout] ?? []) }
                }
                health.execute(query)
            }
            // The session might have changed while HealthKit was queried.
            guard latest?.id == session.id else { return }
            let used = Set(store.completedTrainings.filter { $0.id != session.id }.compactMap(\.healthWorkoutID))
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            matchesSessionID = session.id
            matches = workouts.compactMap { workout in
                guard workout.workoutActivityType == .traditionalStrengthTraining || workout.workoutActivityType == .functionalStrengthTraining,
                      !used.contains(workout.uuid) else { return nil }
                let overlap = min(workout.endDate, session.endedAt).timeIntervalSince(max(workout.startDate, session.startedAt))
                guard overlap > 0, overlap >= session.endedAt.timeIntervalSince(session.startedAt) * 0.5,
                      overlap >= workout.duration * 0.5,
                      let energy = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                      energy.isFinite, energy >= 0 else { return nil }
                return HealthWorkoutMatch(id: workout.uuid, start: workout.startDate, end: workout.endDate, calories: energy)
            }.sorted { $0.start > $1.start }
            if matches.count == 1 { save(matches[0]) }
            else if matches.count > 1 { choosing = true; message = "请选择对应的健康训练。" }
            else { message = "未找到可用的对应训练；请确认手表训练已结束并同步，及健康读取权限。" }
        } catch { message = "读取失败：\(error.localizedDescription)" }
    }

    private func save(_ match: HealthWorkoutMatch) {
        guard let session = latest, session.id == matchesSessionID, let index = store.completedTrainings.firstIndex(where: { $0.id == session.id }) else { return }
        store.completedTrainings[index].healthWorkoutID = match.id
        store.completedTrainings[index].healthCalories = match.calories
        message = "已关联 Apple 健康中的力量训练。"
    }
}
