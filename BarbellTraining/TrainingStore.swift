import Foundation
import AudioToolbox
import AVFoundation

enum TrainingSound {
    private static var players: [String: AVAudioPlayer] = [:]
    private static let audioQueue = DispatchQueue(label: "com.barbelltraining.sound", qos: .userInitiated)

    static func tap() { play("tap", fallback: 1104) }
    static func confirm() { play("confirm", fallback: 1103) }
    static func adjust() { play("adjust", fallback: 1105) }

    private static func play(_ name: String, fallback: SystemSoundID) {
        audioQueue.async {
            playOnAudioQueue(name, fallback: fallback)
        }
    }

    private static func playOnAudioQueue(_ name: String, fallback: SystemSoundID) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if let player = players[name] {
                player.currentTime = 0
                if player.play() { return }
            } else if let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "TrainingSounds") {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[name] = player
                if player.play() { return }
            }
        } catch {
            // 系统音效作为资源或音频会话不可用时的备用。
        }
        AudioServicesPlaySystemSound(fallback)
    }
}

struct Plate: Identifiable, Codable {
    var id = UUID()
    var weight: Double
    var unit: String
    var colorHex: String? = nil
    var availablePairs: Int? = nil
    var kilograms: Double { unit == "lb" ? weight * 0.45359237 : weight }
    var label: String { "\(weight.formattedWeight) \(unit)" }
}

struct PlateLoad: Identifiable, Codable {
    var id = UUID()
    var weight: Double
    var unit: String
    var count: Int
    var kilograms: Double { unit == "lb" ? weight * 0.45359237 : weight }
    var label: String { "\(weight.formattedWeight) \(unit)" }
}

struct TrainingSet: Identifiable, Codable {
    var id = UUID()
    var date = Date()
    var weight: Double
    var reps: Int
    var plates: String
    var note: String? = nil
    var barWeight: Double? = nil
    var loads: [PlateLoad]? = nil
    var planID: UUID? = nil
}

struct TrainingPlanAction: Identifiable, Codable {
    var id = UUID()
    var name: String
    var target: Int
    var reps: Int? = nil
}

struct TrainingPlan: Codable {
    var id = UUID()
    var target: Int
    var hasCelebrated: Bool? = nil
    var startedAt: Date? = nil
    var actions: [TrainingPlanAction]? = nil

    var isValid: Bool {
        guard let actions = actions else { return (1...999).contains(target) }
        let names = actions.map { TrainingStore.actionKey($0.name) }
        return !actions.isEmpty && actions.count <= 20 && names.allSatisfy { !$0.isEmpty } &&
            Set(names).count == names.count && actions.allSatisfy { (1...999).contains($0.target) && ($0.reps == nil || (1...999).contains($0.reps!)) } &&
            target == actions.reduce(0) { $0 + $1.target }
    }
}

struct CompletedTraining: Identifiable, Codable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var healthWorkoutID: UUID? = nil
    var healthCalories: Double? = nil
}

extension Double {
    var formattedWeight: String {
        String(format: "%.2f", self).replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
    }
}

final class TrainingStore: ObservableObject {
    @Published var plates: [Plate] = [] { didSet { save(plates, key: "plates") } }
    @Published var sets: [TrainingSet] = [] { didSet { save(sets, key: "sets"); Task { @MainActor in TrainingWidgetBridge.shared.publish(store: self) } } }
    @Published var activePlan: TrainingPlan? { didSet { save(activePlan, key: "activePlan"); Task { @MainActor in TrainingWidgetBridge.shared.publish(store: self) } } }
    @Published var completedTrainings: [CompletedTraining] = [] { didSet { save(completedTrainings, key: "completedTrainings") } }
    @Published var celebrationID: UUID?
    @Published var recordMessage: String?
    @Published var customActions: [String] = [] { didSet { save(customActions, key: "customActions") } }
    @Published var selected: [UUID: Int] = [:]
    @Published var barWeight: Double = 20 { didSet { defaults.set(barWeight, forKey: "barWeight") } }
    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: "customActions"), let saved = try? JSONDecoder().decode([String].self, from: data) { customActions = saved }
        if let data = defaults.data(forKey: "completedTrainings"), let saved = try? JSONDecoder().decode([CompletedTraining].self, from: data) { completedTrainings = saved }
        if let data = defaults.data(forKey: "activePlan"), let plan = try? JSONDecoder().decode(TrainingPlan.self, from: data), plan.isValid { activePlan = plan }
        if let value = defaults.object(forKey: "barWeight") as? Double, value.isFinite, value > 0 { barWeight = value }
        if let data = defaults.data(forKey: "plates"), let saved = try? JSONDecoder().decode([Plate].self, from: data) {
            plates = saved
        }
        if let data = defaults.data(forKey: "sets"), let saved = try? JSONDecoder().decode([TrainingSet].self, from: data) {
            sets = saved
        }
    }

    var total: Double {
        barWeight + plates.reduce(0) { $0 + $1.kilograms * Double(selected[$1.id, default: 0]) * 2 }
    }

    func savePlate(id: UUID? = nil, weight: Double, unit: String, colorHex: String, availablePairs: Int) -> Bool {
        guard weight.isFinite, weight > 0, weight <= 1000, (0...20).contains(availablePairs),
              !plates.contains(where: { $0.id != id && $0.unit == unit && abs($0.weight - weight) < 0.000001 }) else { return false }
        if let id = id, let index = plates.firstIndex(where: { $0.id == id }) {
            plates[index].weight = weight
            plates[index].unit = unit
            plates[index].colorHex = colorHex
            plates[index].availablePairs = availablePairs
        } else {
            plates.append(Plate(weight: weight, unit: unit, colorHex: colorHex, availablePairs: availablePairs))
        }
        return true
    }

    func canAddPlate(_ plate: Plate) -> Bool {
        selected[plate.id, default: 0] < max(0, plate.availablePairs ?? 1)
    }

    func addPlate(_ plate: Plate) {
        guard canAddPlate(plate) else { return }
        selected[plate.id, default: 0] += 1
    }

    func removePlate(_ plate: Plate) {
        plates.removeAll { $0.id == plate.id }
        selected.removeValue(forKey: plate.id)
    }

    var planCompletedCount: Int {
        guard let plan = activePlan else { return 0 }
        return sets.filter { $0.planID == plan.id }.count
    }

    func completedCount(for action: TrainingPlanAction) -> Int {
        guard let plan = activePlan else { return 0 }
        let key = Self.actionKey(action.name)
        return sets.filter { $0.planID == plan.id && Self.actionKey($0.note ?? "") == key }.count
    }

    var planProgressCount: Int {
        guard let actions = activePlan?.actions else { return planCompletedCount }
        return actions.reduce(0) { $0 + min($1.target, completedCount(for: $1)) }
    }

    var planIsComplete: Bool {
        guard let plan = activePlan else { return false }
        return planProgressCount >= plan.target
    }

    func finishTraining() {
        guard let plan = activePlan else { return }
        if let start = plan.startedAt, start < Date(), planCompletedCount > 0 {
            completedTrainings.insert(CompletedTraining(id: plan.id, startedAt: start, endedAt: Date()), at: 0)
        }
        activePlan = nil
    }

    static func actionKey(_ value: String) -> String {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return name == "推肩" ? "推举" : name
    }

    static let standardActions = ["深蹲", "卧推", "硬拉", "推举", "划船"]

    func rememberCustomAction(_ value: String) {
        let name = Self.actionKey(value)
        guard !name.isEmpty,
              !Self.standardActions.contains(where: { Self.actionKey($0) == name }),
              !customActions.contains(where: { Self.actionKey($0) == name }) else { return }
        customActions.append(name)
    }

    func actionSets(_ action: String) -> [TrainingSet] {
        let key = Self.actionKey(action)
        guard !key.isEmpty else { return [] }
        return sets.filter { Self.actionKey($0.note ?? "") == key }
    }

    static func isLowerRecord(_ lhs: TrainingSet, _ rhs: TrainingSet) -> Bool {
        lhs.weight == rhs.weight ? lhs.reps < rhs.reps : lhs.weight < rhs.weight
    }

    func recordsBroken(on date: Date) -> [(action: String, current: TrainingSet, previous: TrainingSet?)] {
        guard Calendar.current.isDateInToday(date) else { return [] }
        let start = Calendar.current.startOfDay(for: date)
        let daySets = sets.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let actions = Set(daySets.map { Self.actionKey($0.note ?? "") }.filter { !$0.isEmpty })
        return actions.sorted().compactMap { action in
            guard let current = daySets.filter({ Self.actionKey($0.note ?? "") == action }).max(by: Self.isLowerRecord) else { return nil }
            let previous = sets.filter { $0.date < start && Self.actionKey($0.note ?? "") == action }
                .max(by: Self.isLowerRecord)
            guard previous.map({ Self.isLowerRecord($0, current) }) ?? true else { return nil }
            return (action: action, current: current, previous: previous)
        }
    }

    func record(reps: Int, note: String) {
        let action = Self.actionKey(note)
        let best = actionSets(action).max(by: Self.isLowerRecord)
        let isRecord = best.map { total > $0.weight || (total == $0.weight && reps > $0.reps) } ?? true
        recordMessage = !action.isEmpty && isRecord
            ? "\(action) · 新纪录 \(total.formattedWeight) kg × \(reps) 次" : nil
        let wasComplete = planIsComplete
        let loads = plates.compactMap { plate -> PlateLoad? in
            let count = selected[plate.id, default: 0]
            return count > 0 ? PlateLoad(weight: plate.weight, unit: plate.unit, count: count) : nil
        }
        sets.insert(TrainingSet(weight: total, reps: reps, plates: Self.describe(loads), note: note, barWeight: barWeight, loads: loads, planID: activePlan?.id), at: 0)
        if var plan = activePlan, plan.hasCelebrated != true,
           !wasComplete, planIsComplete {
            plan.hasCelebrated = true
            activePlan = plan
            let celebration = UUID()
            celebrationID = celebration
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.5) { [weak self] in
                if self?.celebrationID == celebration { self?.celebrationID = nil }
            }
        }
    }

    static func describe(_ loads: [PlateLoad]) -> String {
        let text = loads.filter { $0.count > 0 }.map { "\($0.label) × \($0.count) 对" }.joined(separator: "、")
        return text.isEmpty ? "空杆" : text
    }

    func backup() -> TrainingBackup { TrainingBackup(version: 1, plates: plates, sets: sets, barWeight: barWeight, activePlan: activePlan, completedTrainings: completedTrainings, customActions: customActions) }

    func restore(_ backup: TrainingBackup) {
        plates = backup.plates
        sets = backup.sets
        barWeight = backup.barWeight
        selected.removeAll()
        celebrationID = nil
        activePlan = backup.activePlan
        completedTrainings = backup.completedTrainings ?? []
        if let actions = backup.customActions { customActions = actions }
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}

struct TrainingBackup: Codable {
    var version: Int
    var plates: [Plate]
    var sets: [TrainingSet]
    var barWeight: Double
    var activePlan: TrainingPlan? = nil
    var completedTrainings: [CompletedTraining]? = nil
    var customActions: [String]? = nil

    var isValid: Bool {
        (completedTrainings ?? []).allSatisfy { $0.startedAt < $0.endedAt && ($0.healthCalories == nil || ($0.healthCalories!.isFinite && $0.healthCalories! >= 0)) } &&
        Set((completedTrainings ?? []).map { $0.id }).count == (completedTrainings ?? []).count &&
        version == 1 && (activePlan == nil || activePlan!.isValid) && barWeight.isFinite && barWeight > 0 && barWeight <= 1000 &&
        Set(plates.map { $0.id }).count == plates.count && Set(sets.map { $0.id }).count == sets.count &&
        plates.allSatisfy { $0.weight.isFinite && $0.weight > 0 && $0.weight <= 1000 && ["kg", "lb"].contains($0.unit) && (0...20).contains($0.availablePairs ?? 1) } &&
        sets.allSatisfy { set in
            set.weight.isFinite && set.weight >= 0 && set.reps > 0 &&
            (set.barWeight == nil || (set.barWeight!.isFinite && set.barWeight! > 0 && set.barWeight! <= 1000)) &&
            (set.loads?.allSatisfy { $0.weight.isFinite && $0.weight > 0 && $0.weight <= 1000 && ["kg", "lb"].contains($0.unit) && $0.count >= 0 && $0.count <= 999 } ?? true)
        }
    }
}
