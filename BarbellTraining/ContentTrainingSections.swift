import SwiftUI
import UIKit

extension ContentView {
    var weightSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "scalemass")
                    Text("当前总重量")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(store.total, specifier: "%.2f")")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("kg")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(TrainingTheme.accent)
                .padding(.top, 8)

                Text("约 \((store.total / 0.45359237).formattedWeight) lb")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("包含 \(store.barWeight.formattedWeight) kg 杠铃杆 · 两侧对称")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                BarbellView(plates: store.plates, selected: store.selected)
                    .frame(height: 96)
                    .padding(.top, 18)
                Text(singleSideDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
        }
    }

    var singleSideDescription: String {
        let parts = store.plates.sorted { $0.kilograms > $1.kilograms }.compactMap { plate -> String? in
            let count = store.selected[plate.id, default: 0]
            return count > 0 ? "\(plate.label) × \(count)" : nil
        }
        return parts.isEmpty ? "单边：未装片" : "单边：" + parts.joined(separator: " + ")
    }

    func plateSection(includeAdd: Bool = true) -> some View {
        Section {
            ForEach(sortedPlates) { plate in
                HStack(spacing: 0) {
                    Circle().fill(Color(hex: plate.colorHex))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plate.label).font(.headline)
                        Text(plate.unit == "lb"
                             ? "约 \(plate.kilograms.formattedWeight) kg"
                             : "约 \((plate.kilograms / 0.45359237).formattedWeight) lb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("库存 \(plate.availablePairs ?? 1) 对")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 0) {
                        Button { store.selected[plate.id, default: 0] -= 1 } label: {
                            Image(systemName: "minus").frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .disabled(store.selected[plate.id, default: 0] == 0)
                        .accessibilityLabel("减少一对 \(plate.label)")
                        Text("\(store.selected[plate.id, default: 0]) 对")
                            .font(.subheadline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                            .frame(minWidth: 36)
                            .accessibilityLabel("当前 \(store.selected[plate.id, default: 0]) 对")
                        Button { store.addPlate(plate) } label: {
                            Image(systemName: "plus").frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .disabled(!store.canAddPlate(plate))
                        .accessibilityLabel("增加一对 \(plate.label)")
                    }
                    .buttonStyle(.borderless)
                    .tint(.primary)
                    .modifier(PlateControlMaterial())
                    Button { editingPlate = plate } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.secondary)
                            .frame(width: 48, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("编辑 \(plate.label) 规格")

                }.padding(.vertical, 4)
            }
            .onDelete { offsets in
                let removed = offsets.map { sortedPlates[$0] }
                removed.forEach { store.removePlate($0) }
            }
            if store.plates.isEmpty { Text("还没有规格，请添加自己的杠铃片。") .foregroundStyle(.secondary) }
            if includeAdd {
                Button { showAdd = true } label: { TrainingRowLabel(title: "添加杠铃片规格", systemImage: "plus.circle") }
                    .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Text("杠铃片规格")
                Spacer()
                Button { plateSortAscending.toggle() } label: {
                    Label(plateSortAscending ? "从轻到重" : "从重到轻", systemImage: "arrow.up.arrow.down")
                        .textCase(nil)
                }
                .accessibilityHint("点击切换排序方向")
            }
        } footer: {
            Text("使用加减按钮调整数量；点击图标编辑，左滑删除规格。")
        }
    }

    var sortedPlates: [Plate] {
        store.plates.enumerated().sorted { left, right in
            if left.element.kilograms == right.element.kilograms { return left.offset < right.offset }
            return plateSortAscending ? left.element.kilograms < right.element.kilograms : left.element.kilograms > right.element.kilograms
        }.map { $0.element }
    }

    var barSection: some View {
        Section("杠铃杆") {
            Button { showBarSettings = true } label: {
                TrainingRowLabel(title: "设置杆重：\(store.barWeight.formattedWeight) kg", systemImage: "scalemass")
            }.buttonStyle(.plain)
        }
    }

    var recordSection: some View {
        Section("记录训练") {
            Stepper("每组次数：\(reps) 次", value: $reps, in: 1...999)
            TextField("备注，例如卧推、深蹲、硬拉", text: $note)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(["深蹲", "卧推", "硬拉", "推举", "划船"], id: \.self) { name in
                        Button(name) { note = name }
                            .buttonStyle(TrainingTagStyle(selected: note == name))
                            .accessibilityHint("点击会替换备注内容")
                    }
                }
            }
            ActionProgressView(action: note)
            Text("选择动作会替换备注内容")
                .font(.caption).foregroundStyle(.secondary)
            Button { recordSet() } label: {
                Label("记录这一组", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity)
            }.buttonStyle(TrainingActionStyle(kind: .primary))
            Button { reusePreviousSet() } label: { Label("复用上一组", systemImage: "arrow.uturn.backward") }
                .buttonStyle(TrainingActionStyle(kind: .secondary))
                .disabled(store.sets.isEmpty)
            Button { store.selected.removeAll() } label: {
                Label("清空当前装片", systemImage: "xmark.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.plain)
        }
    }

    func reusePreviousSet() {
        let action = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !action.isEmpty else {
            reuseMessage = "请先选择或输入动作。"
            return
        }
        guard let set = store.actionSets(action).max(by: { $0.date < $1.date }) else {
            reuseMessage = "没有找到该动作的训练记录。"
            return
        }
        guard let loads = set.loads, let barWeight = set.barWeight else {
            reuseMessage = "这条旧记录没有完整装片明细，无法复用。"
            return
        }
        guard abs(barWeight - store.barWeight) < 0.000001 else {
            reuseMessage = "上一组的杆重与当前杆重不同，请先调整杆重。"
            return
        }
        var selection: [UUID: Int] = [:]
        for load in loads where load.count > 0 {
            guard let plate = store.plates.first(where: { $0.unit == load.unit && abs($0.weight - load.weight) < 0.000001 }) else {
                reuseMessage = "当前规格中缺少上一组使用的杠铃片，请先添加对应规格。"
                return
            }
            selection[plate.id, default: 0] += load.count
        }
        store.selected = selection
        reps = set.reps
    }

    var todayEnergySummary: String {
        let sessions = store.completedTrainings.filter { Calendar.current.isDateInToday($0.endedAt) }
        let weight = Double(energyBodyWeight.replacingOccurrences(of: ",", with: ".")) ?? 0
        var calories = 0.0
        var known = 0
        var estimated = false
        var missing = false
        for session in sessions {
            if let value = session.healthCalories {
                calories += value
                known += 1
            } else if let value = TrainingEnergy.estimate(session: session, weight: weight, sets: store.sets) {
                calories += value
                known += 1
                estimated = true
            } else {
                missing = true
            }
        }
        let sessionIDs = Set(sessions.map(\.id))
        if todaySets.contains(where: { set in set.planID.map { !sessionIDs.contains($0) } ?? true }) { missing = true }
        guard known > 0 else { return "暂无数据" }
        return "\(estimated ? "约 " : "")\(Int(calories.rounded())) 千卡\(missing ? " · 部分" : "")"
    }

    func statisticsSection(inner: Bool = false) -> some View {
        Section {
            HStack(alignment: .top, spacing: 8) {
                overviewStat("完成", value: "\(todaySets.count) 组", color: TrainingTheme.accent)
                overviewStat("训练量", value: "\(todaySets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }.formattedWeight) kg", color: TrainingTheme.teal)
                overviewStat("已统计消耗", value: todayEnergySummary, color: .primary)
            }
            .padding(.vertical, 2)
            NavigationLink { TrainingInsightsView() } label: {
                Label("训练总结", systemImage: "chart.bar.doc.horizontal")
            }
            if let message = store.recordMessage {
                Label(message, systemImage: "trophy.fill").foregroundStyle(TrainingTheme.accent)
            }
            if todaySets.isEmpty {
                Text("今天还没有训练记录").foregroundStyle(.secondary)
            }
            ForEach(todaySets) { set in
                Button { selectedTodaySetID = set.id; editingTodaySet = set } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(set.note?.isEmpty == false ? set.note! : "未分类")
                                .font(.subheadline.weight(.semibold)).lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(set.weight.formattedWeight) kg × \(set.reps) 次")
                                .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(set.plates).lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 4)
                            Text(set.date.formatted(date: .abbreviated, time: .standard))
                                .lineLimit(1).minimumScaleFactor(0.7).monospacedDigit()
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 1)
                }.buttonStyle(TrainingRecordSelectionStyle(selected: selectedTodaySetID == set.id))
            }
            .onDelete { offsets in
                pendingTodayDelete = offsets.map { todaySets[$0].id }
                showTodayDeleteConfirmation = true
            }
            Button {
                if inner { selectedInnerTab = 1 }
                else { showHistory = true }
            } label: {
                TrainingRowLabel(title: "查看训练记录", systemImage: "clock.arrow.circlepath")
            }.buttonStyle(.plain)
        } header: {
            if !inner { Text("今日统计") }
        }
    }

    func overviewStat(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color)
                .lineLimit(2).minimumScaleFactor(0.7).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    var todaySets: [TrainingSet] {
        store.sets.filter { Calendar.current.isDateInToday($0.date) }.sorted { $0.date > $1.date }
    }

}

private struct PlateControlMaterial: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
}
