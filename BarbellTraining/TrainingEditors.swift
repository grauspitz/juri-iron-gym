import SwiftUI

struct BarWeightView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.dismiss) private var dismiss
    @State private var weight = ""
    @State private var error = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                TextField("杆重（kg）", text: $weight).keyboardType(.decimalPad)
                Text("仅影响当前及今后记录，不改变已有记录。") .font(.footnote).foregroundStyle(.secondary)
                if error { Text("请输入大于 0 且不超过 1000 的重量。") .foregroundStyle(.red) }
                }.listRowBackground(TrainingTheme.card)
            }
            .scrollContentBackground(.hidden)
            .background(TrainingBackground())
            .navigationTitle("设置杆重")
            .onAppear { weight = store.barWeight.formattedWeight }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("返回", systemImage: "chevron.left") }.tint(.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let value = Double(weight.replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0, value <= 1000 else { error = true; return }
                        store.barWeight = value
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EditNoteView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.dismiss) private var dismiss
    let set: TrainingSet
    @State private var note: String
    @State private var reps: Int
    @State private var date: Date
    @State private var barWeight: String
    @State private var loads: [PlateLoad]
    @State private var useLoads: Bool
    @State private var error = false

    init(set: TrainingSet) {
        self.set = set
        _note = State(initialValue: set.note ?? "")
        _reps = State(initialValue: set.reps)
        _date = State(initialValue: set.date)
        _barWeight = State(initialValue: (set.barWeight ?? 20).formattedWeight)
        _loads = State(initialValue: set.loads ?? [])
        _useLoads = State(initialValue: set.loads != nil && set.barWeight != nil)
    }

    private var parsedBar: Double? {
        guard let value = Double(barWeight.replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0, value <= 1000 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                DatePicker("时间", selection: $date)
                Stepper("次数：\(reps) 次", value: $reps, in: 1...999)
                TextField("备注，例如卧推、深蹲、硬拉", text: $note, axis: .vertical)
                if useLoads {
                    Section("装片和总重量") {
                        HStack {
                            Text("杆重 (kg)")
                            TextField("杆重", text: $barWeight).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        ForEach($loads) { $load in
                            Stepper("\(load.label)：\(load.count) 对", value: $load.count, in: 0...999)
                        }
                        if store.plates.contains(where: { plate in !loads.contains(where: { $0.weight == plate.weight && $0.unit == plate.unit }) }) {
                            Menu("添加现有规格") {
                                ForEach(store.plates.filter { plate in !loads.contains(where: { $0.weight == plate.weight && $0.unit == plate.unit }) }) { plate in
                                    Button(plate.label) { loads.append(PlateLoad(weight: plate.weight, unit: plate.unit, count: 1)) }
                                }
                            }
                        }
                        if let bar = parsedBar {
                            let total = bar + loads.reduce(0) { $0 + $1.kilograms * Double($1.count) * 2 }
                            Text("总重量：\(total, specifier: "%.2f") kg")
                        }
                        if error { Text("请输入有效的杆重。") .foregroundStyle(.red) }
                    }
                } else {
                    Section("原始记录") {
                        Text("\(set.weight, specifier: "%.2f") kg · \(set.plates)")
                        Text("旧记录没有装片明细。可保留原重量，或选择当前规格重新配置；重新配置后重量会重新计算。") .font(.footnote).foregroundStyle(.secondary)
                        Button("重新配置装片") {
                            loads = store.plates.map { PlateLoad(weight: $0.weight, unit: $0.unit, count: 0) }
                            barWeight = store.barWeight.formattedWeight
                            useLoads = true
                        }
                    }
                }
                }.listRowBackground(TrainingTheme.card)
            }
            .scrollContentBackground(.hidden)
            .background(TrainingBackground())
            .navigationTitle("编辑训练记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Label("返回", systemImage: "chevron.left") }.tint(.primary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if useLoads && parsedBar == nil { error = true; return }
                        if let index = store.sets.firstIndex(where: { $0.id == set.id }) {
                            var updated = store.sets[index]
                            updated.date = date
                            updated.reps = reps
                            updated.note = note
                            if useLoads, let bar = parsedBar {
                                let activeLoads = loads.filter { $0.count > 0 }
                                updated.barWeight = bar
                                updated.loads = activeLoads
                                updated.weight = bar + activeLoads.reduce(0) { $0 + $1.kilograms * Double($1.count) * 2 }
                                updated.plates = TrainingStore.describe(activeLoads)
                            }
                            store.sets[index] = updated
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
