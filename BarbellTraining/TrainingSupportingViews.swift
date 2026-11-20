import SwiftUI
import UIKit

struct AddPlateView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.dismiss) private var dismiss
    let plate: Plate?
    let onClose: (() -> Void)?
    @State private var weight: String
    @State private var unit: String
    @State private var color: Color
    @State private var error = false
    @State private var availablePairs: Int

    init(plate: Plate? = nil, onClose: (() -> Void)? = nil) {
        self.plate = plate
        self.onClose = onClose
        _weight = State(initialValue: plate?.weight.formattedWeight ?? "")
        _unit = State(initialValue: plate?.unit ?? "kg")
        _color = State(initialValue: Color(hex: plate?.colorHex))
        _availablePairs = State(initialValue: plate?.availablePairs ?? 1)
    }

    private func close() {
        if let onClose = onClose { onClose() } else { dismiss() }
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                TextField("单片重量", text: $weight).keyboardType(.decimalPad)
                Picker("单位", selection: $unit) { Text("公斤 (kg)").tag("kg"); Text("磅 (lb)").tag("lb") }
                ColorPicker("颜色", selection: $color, supportsOpacity: false)
                Stepper("库存：\(availablePairs) 对", value: $availablePairs, in: 0...20)
                Text("输入单片的重量，使用时按一对计算。") .font(.footnote).foregroundStyle(.secondary)
                if error { Text("请输入大于 0 且不超过 1000 的重量，规格不能重复。") .foregroundStyle(.red) }
                }.listRowBackground(TrainingTheme.card)
            }
            .scrollContentBackground(.hidden)
            .background(TrainingBackground())
            .navigationTitle(plate == nil ? "添加规格" : "编辑规格")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button { close() } label: { Label("返回", systemImage: "chevron.left") }.buttonStyle(TrainingModalButtonStyle()).tint(.primary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let normalized = weight.replacingOccurrences(of: ",", with: ".")
                        if let value = Double(normalized), store.savePlate(id: plate?.id, weight: value, unit: unit, colorHex: color.hexValue, availablePairs: availablePairs) { close() }
                        else { error = true }
                    }
                    .buttonStyle(TrainingModalButtonStyle())
                }
            }
        }
    }
}

extension Color {
    init(hex: String?) {
        let value = UInt64(hex ?? "A81A5C", radix: 16) ?? 0xA81A5C
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }

    var hexValue: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedDate = Date()

    private var daySets: [TrainingSet] {
        store.sets.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .compact {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            TrainingShareButton(date: selectedDate)
                            TrainingCalendar(selectedDate: $selectedDate, sets: store.sets)
                                .padding(16)
                                .background(TrainingTheme.card, in: RoundedRectangle(cornerRadius: 20))
                            VStack(alignment: .leading, spacing: 10) {
                                NavigationLink("查看当天记录（\(daySets.count) 组）") { DayHistoryView(date: selectedDate) }
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .background(TrainingTheme.card, in: RoundedRectangle(cornerRadius: 16))
                                Text("选择日期后，点击查看当天的训练记录。")
                                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
                            }
                        }
                        .padding(16)
                    }
                } else {
                    List {
                        Section {
                            TrainingShareButton(date: selectedDate)
                            TrainingCalendar(selectedDate: $selectedDate, sets: store.sets)
                        }.listRowBackground(TrainingTheme.card)
                        Section {
                            NavigationLink("查看当天记录（\(daySets.count) 组）") { DayHistoryView(date: selectedDate) }
                        } footer: { Text("选择日期后，点击查看当天的训练记录。") }
                        .listRowBackground(TrainingTheme.card)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(TrainingBackground())
            .navigationTitle("训练记录")
            .navigationBarTitleDisplayMode(horizontalSizeClass == .compact ? .inline : .automatic)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Label("返回", systemImage: "chevron.left") }.tint(.primary) } }
        }
    }
}

struct DayHistoryView: View {
    @EnvironmentObject private var store: TrainingStore
    let date: Date
    @State private var editingSet: TrainingSet?
    @State private var selectedRecordID: UUID?
    @State private var pendingDelete: [UUID] = []
    @State private var showDeleteConfirmation = false
    @State private var selecting = false
    @State private var selectedIDs: Set<UUID> = []

    private var daySets: [TrainingSet] {
        store.sets.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        List {
            if daySets.isEmpty { Text("当天没有训练记录").foregroundStyle(.secondary).listRowBackground(TrainingTheme.card) }
            ForEach(daySets) { set in
                Button {
                    if selecting {
                        if selectedIDs.contains(set.id) { selectedIDs.remove(set.id) }
                        else { selectedIDs.insert(set.id) }
                    } else { selectedRecordID = set.id; editingSet = set }
                } label: {
                    HStack {
                    if selecting {
                        Image(systemName: selectedIDs.contains(set.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(TrainingTheme.accent)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("\(set.weight, specifier: "%.2f") kg × \(set.reps) 次").font(.headline)
                            Spacer()
                            Text(set.date.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                        Text(set.plates).font(.caption).foregroundStyle(.secondary)
                        if let note = set.note, !note.isEmpty { Text(note).font(.subheadline) }
                        else { Text("点击编辑记录").font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical, 3)
                    }
                }.buttonStyle(TrainingRecordSelectionStyle(selected: selecting ? selectedIDs.contains(set.id) : selectedRecordID == set.id))
            }.onDelete { offsets in
                pendingDelete = offsets.map { daySets[$0].id }
                showDeleteConfirmation = true
            }.listRowBackground(TrainingTheme.card)
        }
        .scrollContentBackground(.hidden)
        .background(TrainingBackground())
        .alert("删除训练记录？", isPresented: $showDeleteConfirmation) {
            Button("删除", role: .destructive) {
                store.sets.removeAll { pendingDelete.contains($0.id) }
                selectedIDs.removeAll()
                selecting = false
            }
            Button("取消", role: .cancel) {}
        } message: { Text("将删除所选的 \(pendingDelete.count) 条记录，删除后无法撤销。") }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if selecting {
                    Button(selectedIDs.count == daySets.count ? "取消全选" : "全选") {
                        selectedIDs = selectedIDs.count == daySets.count ? [] : Set(daySets.map { $0.id })
                    }
                    Button("删除") { pendingDelete = Array(selectedIDs); showDeleteConfirmation = true }
                        .disabled(selectedIDs.isEmpty)
                    Button("取消") { selecting = false; selectedIDs.removeAll() }
                } else {
                    Button("选择") { selecting = true }.disabled(daySets.isEmpty)
                }
            }
        }
        .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
        .tint(.primary)
        .sheet(item: $editingSet) { set in EditNoteView(set: set) }
    }
}


struct BarbellView: View {
    let plates: [Plate]
    let selected: [UUID: Int]

    private var loadedPlates: [Plate] {
        plates.sorted { $0.kilograms > $1.kilograms }.flatMap { plate in
            Array(repeating: plate, count: max(0, selected[plate.id, default: 0]))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let loaded = loadedPlates
            let maximum = loaded.first?.kilograms ?? 1
            let thickness = min(7, size.width * 0.12 / CGFloat(max(loaded.count, 1)))
            ZStack {
                Canvas { context, size in
                    let bar = CGRect(x: 4, y: size.height / 2 - 5, width: max(0, size.width - 8), height: 10)
                    let metal = Gradient(stops: [
                        .init(color: Color(white: 0.28), location: 0),
                        .init(color: Color(white: 0.82), location: 0.3),
                        .init(color: Color(white: 0.96), location: 0.46),
                        .init(color: Color(white: 0.42), location: 0.75),
                        .init(color: Color(white: 0.22), location: 1)
                    ])
                    context.fill(Path(roundedRect: bar, cornerRadius: 4), with: .linearGradient(metal, startPoint: CGPoint(x: 0, y: bar.minY), endPoint: CGPoint(x: 0, y: bar.maxY)))
                }
                .zIndex(-Double(loaded.count) - 1)
                ForEach(Array(loaded.enumerated()), id: \.offset) { index, plate in
                    let height = 34 + 48 * CGFloat(sqrt(plate.kilograms / maximum))
                    let width = height * 1024 / 1536
                    let offset = size.width * 0.28 + CGFloat(index) * thickness
                    ForEach([-1, 1], id: \.self) { side in
                        let direction = CGFloat(side)
                        RealisticPlateView(color: Color(hex: plate.colorHex), showFace: index == 0)
                            .frame(width: width, height: height)
                            .overlay {
                                if index == 0 {
                                    Rectangle()
                                        .fill(LinearGradient(colors: [.black, .gray, .white, .gray, .black], startPoint: .top, endPoint: .bottom))
                                        .frame(width: width * 0.46, height: height * 0.045)
                                        .position(x: width * 0.80, y: height * 0.5)
                                }
                            }
                            .scaleEffect(x: side < 0 ? 1 : -1, y: 1)
                            .position(x: size.width / 2 + direction * (offset + width * 0.077), y: size.height / 2)
                            .zIndex(-Double(index))
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .accessibilityLabel("杠铃装片示意图，较重的杠铃片靠内，两侧对称")
    }
}

