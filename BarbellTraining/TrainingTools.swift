import SwiftUI

struct WeightCalculatorSection: View {
    @EnvironmentObject private var store: TrainingStore
    var pendingSelection: Binding<[UUID: Int]?>? = nil
    @State private var target = ""
    @State private var unit = "kg"
    @State private var message: String?
    @State private var proposal: [UUID: Int]?
    @State private var proposalTotal: Double?

    var body: some View {
        Section("自动配重") {
            HStack {
                TextField("目标总重量", text: $target).keyboardType(.decimalPad)
                Picker("单位", selection: $unit) {
                    Text("kg").tag("kg")
                    Text("lb").tag("lb")
                }.pickerStyle(.segmented).frame(width: 120)
            }
            Button { calculate() } label: { Label("计算配重", systemImage: "equal.circle") }
                .buttonStyle(TrainingActionStyle(kind: .secondary))
            if let message = message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            if let proposal = proposal, let total = proposalTotal {
                Text("实际重量：\(total.formattedWeight) kg · 约 \((total / 0.45359237).formattedWeight) lb")
                    .font(.subheadline.weight(.medium))
                if let input = Double(target.replacingOccurrences(of: ",", with: ".")) {
                    let displayedTotal = unit == "lb" ? total / 0.45359237 : total
                    let difference = displayedTotal - input
                    Text(abs(difference) < 0.005 ? "接近目标重量" : "比目标\(difference > 0 ? "重" : "轻")约 \(abs(difference).formattedWeight) \(unit)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(store.plates.filter { proposal[$0.id, default: 0] > 0 }.sorted { $0.kilograms > $1.kilograms }) { plate in
                    Label("\(plate.label) × \(proposal[plate.id, default: 0]) 对", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(TrainingTheme.teal)
                }
                if pendingSelection == nil {
                    Button { store.selected = proposal; self.proposal = nil; proposalTotal = nil } label: {
                        Label("应用配重", systemImage: "checkmark")
                    }.buttonStyle(TrainingActionStyle(kind: .primary))
                }
            }
        }
        .onChange(of: target) { _ in clear() }
        .onChange(of: unit) { _ in clear() }
        .onChange(of: store.plates.map { "\($0.id)-\($0.weight)-\($0.unit)-\($0.availablePairs ?? 1)" }) { _ in clear() }
        .onChange(of: store.barWeight) { _ in clear() }
    }

    private func clear() {
        proposal = nil; proposalTotal = nil; message = nil
        if let pendingSelection = pendingSelection { pendingSelection.wrappedValue = nil }
    }

    private func calculate() {
        clear()
        guard let input = Double(target.replacingOccurrences(of: ",", with: ".")), input.isFinite, input > 0 else {
            message = "请输入有效的目标重量。"; return
        }
        let kilograms = unit == "lb" ? input * 0.45359237 : input
        guard kilograms <= 500 else {
            message = "目标重量不能超过 500 kg。"; return
        }
        // Any nearest combination above the target is at most one plate heavier than it.
        let targetSide = Int(((kilograms - store.barWeight) / 2 * 1_000_000).rounded())
        let maxPlate = store.plates.filter { ($0.availablePairs ?? 1) > 0 }
            .map { Int(($0.kilograms * 1_000_000).rounded()) }.max() ?? 0
        let upperBound = max(0, targetSide) + maxPlate
        var states: [Int: [UUID: Int]] = [0: [:]]
        for plate in store.plates {
            let weight = Int((plate.kilograms * 1_000_000).rounded())
            guard weight > 0 else { continue }
            let limit = min(plate.availablePairs ?? 1, 20)
            var next = states
            for (sum, selection) in states {
                for count in 1...max(limit, 1) where count <= limit {
                    let result = sum + weight * count
                    if result > upperBound { break }
                    if next[result] == nil {
                        var updated = selection
                        updated[plate.id] = count
                        next[result] = updated
                        if next.count > 100_000 {
                            message = "规格组合过多，请减少库存数量后重试。"; return
                        }
                    }
                }
            }
            states = next
        }
        guard let closest = states.keys.min(by: {
            let left = abs($0 - targetSide), right = abs($1 - targetSide)
            return left == right ? $0 < $1 : left < right
        }), let result = states[closest] else { return }
        proposal = result
        if let pendingSelection = pendingSelection { pendingSelection.wrappedValue = result }
        proposalTotal = store.barWeight + store.plates.reduce(0) { $0 + $1.kilograms * Double(result[$1.id, default: 0]) * 2 }
        message = result.isEmpty ? "最接近的方案是空杆。" : "按每侧相同数量装片；请核对实际重量。"
    }
}

struct RestTimerSection: View {
    @Binding var deadline: Date?
    @Binding var duration: Int
    @Binding var pausedSeconds: Int?

    var body: some View {
        Section("组间休息") {
            Picker("休息时长", selection: $duration) {
                Text("60 秒").tag(60)
                Text("90 秒").tag(90)
                Text("2 分钟").tag(120)
                Text("3 分钟").tag(180)
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let seconds = pausedSeconds ?? deadline.map({ max(0, Int(ceil($0.timeIntervalSince(context.date)))) }) {
                    HStack {
                        Text(seconds == 0 ? "休息结束" : (pausedSeconds != nil ? "已暂停" : "剩余时间"))
                        Spacer()
                        Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                            .monospacedDigit().font(.title3.weight(.semibold))
                    }
                } else {
                    Text("记录一组后自动开始倒计时").foregroundStyle(.secondary)
                }
            }
            if let seconds = pausedSeconds {
                Button("继续计时") { deadline = Date().addingTimeInterval(Double(seconds)); pausedSeconds = nil }
            }
            if deadline != nil || pausedSeconds != nil { Button("关闭计时器") { deadline = nil; pausedSeconds = nil } }
        }
    }
}

private enum WeightStepResult {
    case selection([UUID: Int])
    case unavailable
    case tooManyCombinations
}

private enum WeightStepCalculator {
    private struct Candidate {
        var selection: [UUID: Int]
        var changes: Int
    }

    static func calculate(plates: [Plate], selected: [UUID: Int], increase: Bool) -> WeightStepResult {
        let scale = 1_000_000.0
        let weights = plates.map { Int(($0.kilograms * scale).rounded()) }
        let current = zip(plates, weights).reduce(0) { sum, item in
            sum + item.1 * max(0, selected[item.0.id, default: 0])
        }
        let maxPlate = zip(plates, weights).filter { ($0.0.availablePairs ?? 1) > 0 }.map { $0.1 }.max() ?? 0
        let bound = current + (increase ? maxPlate : 0)
        var states: [Int: Candidate] = [0: Candidate(selection: [:], changes: 0)]
        for (plate, weight) in zip(plates, weights) {
            let limit = max(0, min(plate.availablePairs ?? 1, 20))
            let previous = max(0, selected[plate.id, default: 0])
            var next: [Int: Candidate] = [:]
            for (sum, candidate) in states {
                for count in 0...limit {
                    let total = sum + weight * count
                    if total > bound { break }
                    let changes = candidate.changes + abs(count - previous)
                    if let existing = next[total], existing.changes <= changes { continue }
                    var selection = candidate.selection
                    if count > 0 { selection[plate.id] = count }
                    next[total] = Candidate(selection: selection, changes: changes)
                    if next.count > 100_000 { return .tooManyCombinations }
                }
            }
            states = next
        }
        let matching = states.keys.filter { increase ? $0 > current : $0 < current }
        guard let closest = increase ? matching.min() : matching.max(), let result = states[closest] else {
            return .unavailable
        }
        return .selection(result.selection)
    }
}

struct WeightStepControls: View {
    @EnvironmentObject private var store: TrainingStore
    @State private var message: String?
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 2 : 8) {
            Text("最小调重").font(compact ? .custom("ZCOOLQingKeHuangYou-Regular", size: 14) : .subheadline)
                .lineLimit(1).minimumScaleFactor(0.7)
            if compact {
                ArcadeAdjustButton(symbol: "minus", label: "降低至下一档可配重量", disabled: store.plates.allSatisfy { store.selected[$0.id, default: 0] <= 0 }, playsSound: false) { adjust(increase: false) }
                ArcadeAdjustButton(symbol: "plus", label: "增加至下一档可配重量", disabled: !canIncrease, playsSound: false) { adjust(increase: true) }
            } else {
            Button { adjust(increase: false) } label: {
                Image(systemName: "minus.circle.fill").frame(width: 44, height: 44)
            }.disabled(store.plates.allSatisfy { store.selected[$0.id, default: 0] <= 0 })
                .accessibilityLabel("降低至下一档可配重量")
            Button { adjust(increase: true) } label: {
                Image(systemName: "plus.circle.fill").frame(width: 44, height: 44)
            }.disabled(!canIncrease)
                .accessibilityLabel("增加至下一档可配重量")
            }
        }
        .buttonStyle(.plain)
        .alert("无法调整配重", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private var canIncrease: Bool {
        let current = store.plates.reduce(0.0) { $0 + $1.kilograms * Double(max(0, store.selected[$1.id, default: 0])) }
        let maximum = store.plates.reduce(0.0) { $0 + $1.kilograms * Double(max(0, min($1.availablePairs ?? 1, 20))) }
        return current < maximum - 0.000001
    }

    private func adjust(increase: Bool) {
        switch WeightStepCalculator.calculate(plates: store.plates, selected: store.selected, increase: increase) {
        case .selection(let selection):
            TrainingSound.adjust()
            store.selected = selection
        case .unavailable:
            message = "当前库存没有更\(increase ? "重" : "轻")的配重方案。"
        case .tooManyCombinations:
            message = "库存组合过多，请减少规格或库存数量后重试。"
        }
    }
}


// 外屏配重统一使用草稿，只有确认后才更新训练中的配重。
struct HandheldWeightSettings: View {
    var confirmRequest: Int = 0
    var onClose: () -> Void
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.trainingLandscape) private var trainingLandscape
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0
    @State private var manualSelection: [UUID: Int] = [:]
    @State private var automaticSelection: [UUID: Int]?
    @State private var confirmMessage: String?

    private var screenPanel: Color {
        trainingLandscape ? Color(red: 0.20, green: 0.09, blue: 0.29) : Color(red: 0.08, green: 0.12, blue: 0.12)
    }

    private var screenBackground: Color {
        trainingLandscape ? Color(red: 0.10, green: 0.03, blue: 0.17) : Color(red: 0.025, green: 0.04, blue: 0.05)
    }

    private var selected: [UUID: Int]? {
        mode == 0 ? automaticSelection : manualSelection
    }

    private var selectedTotal: Double {
        store.barWeight + store.plates.reduce(0) { total, plate in
            total + plate.kilograms * Double((selected ?? [:])[plate.id, default: 0]) * 2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消", action: onClose)
                Spacer()
                Text("配重设置").font(.system(size: 15, weight: .bold, design: .monospaced)).tracking(1)
                Spacer()
                if !trainingLandscape {
                    Button("确认") { applySelection() }
                        .buttonStyle(TrainingModalButtonStyle(confirm: true))
                }
            }
            .buttonStyle(TrainingModalButtonStyle())
            .padding(.horizontal, 8)
            .background(screenBackground)
            .layoutPriority(1)
            List {
                Section {
                    Picker("配重方式", selection: $mode) {
                        Text("自动计算").tag(0)
                        Text("手动选片").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(screenPanel.opacity(0.96))
                if mode == 0 {
                    WeightCalculatorSection(pendingSelection: $automaticSelection)
                        .listRowBackground(screenPanel.opacity(0.96))
                } else {
                    Section {
                        if store.plates.isEmpty {
                            Text("还没有杠铃片规格，请在完整功能中添加。")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(store.plates.sorted { $0.kilograms > $1.kilograms }) { plate in
                            Stepper(value: Binding(
                                get: { manualSelection[plate.id, default: 0] },
                                set: { manualSelection[plate.id] = $0 }
                            ), in: 0...max(0, plate.availablePairs ?? 1)) {
                                HStack {
                                    Text(plate.label)
                                    Spacer()
                                    Text("\(manualSelection[plate.id, default: 0]) 对")
                                        .monospacedDigit().foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("每侧相同数量")
                    } footer: {
                        Text("可选数量以已配置的杠铃片库存为准。")
                    }
                    .listRowBackground(screenPanel.opacity(0.96))
                }
            }
            .scrollContentBackground(.hidden)
            if let confirmMessage = confirmMessage {
                Text(confirmMessage).font(.caption).foregroundStyle(.orange).padding(6)
            }
            if selected != nil {
                Text("总重量 \(selectedTotal.formattedWeight) kg")
                    .font(.subheadline.weight(.semibold))
                    .padding(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(screenBackground)
        .environment(\.colorScheme, .dark)
        .onAppear { manualSelection = store.selected }
        .onChange(of: confirmRequest) { _ in applySelection() }
    }

    private func applySelection() {
        guard let selection = selected else {
            confirmMessage = "请先计算配重或选择手动选片。"
            return
        }
        store.selected = selection
        TrainingFeedback.confirm()
        onClose()
    }
}
