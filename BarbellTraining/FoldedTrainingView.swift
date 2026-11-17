import SwiftUI
import UIKit

enum TrainingFeedback {
    static func tap() {
        TrainingSound.tap()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func adjust() {
        TrainingSound.adjust()
        adjustHaptic()
    }
    static func adjustHaptic() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func confirm() {
        TrainingSound.confirm()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func confirmHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct FoldedTrainingView: View {
    @EnvironmentObject private var store: TrainingStore
    @State private var selectedPlateID: UUID?
    @State private var showWeightCalculator = false
    @State private var pendingWeightSelection: [UUID: Int]?
    @State private var controlContentHeight: CGFloat = 0
    @FocusState private var customActionFocused: Bool
    @State private var showCustomActionEditor = false
    @State private var customActionDraft = ""
    let fold: CGRect
    let height: CGFloat
    @Binding var reps: Int
    @Binding var note: String
    @Binding var deadline: Date?
    @Binding var pausedSeconds: Int?
    @Binding var duration: Int
    @Binding var totalDuration: Int
    @Binding var showFullLayout: Bool
    let fullLayout: AnyView
    let record: () -> Void
    let reuse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if showFullLayout {
                    fullLayout
                } else if showWeightCalculator {
                    weightCalculator
                } else {
                    display
                }
            }
                .frame(maxWidth: .infinity)
                .frame(height: max(0, fold.minY))
                .overlay(alignment: .topTrailing) {
                    if showFullLayout || showWeightCalculator {
                        HStack(spacing: 6) {
                            if showWeightCalculator {
                                Button("确认") {
                                    TrainingFeedback.confirm()
                                    if let selection = pendingWeightSelection {
                                        store.selected = selection
                                        pendingWeightSelection = nil
                                        showWeightCalculator = false
                                    }
                                }
                                .disabled(pendingWeightSelection == nil)
                            }
                            Button("返回") {
                                TrainingFeedback.tap()
                                pendingWeightSelection = nil
                                showWeightCalculator = false
                                showFullLayout = false
                            }
                        }
                        .buttonStyle(ControllerButtonStyle(color: .purple))
                        .padding(10)
                    }
                }
                .clipped()
            FoldHinge().frame(height: max(0, fold.height))
                .accessibilityHidden(true)
            controls
                .frame(maxWidth: .infinity)
                .frame(height: max(0, height - fold.maxY))
        }
        .onAppear {
            if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                note = "硬拉"
            }
        }
    }

    private var weightCalculator: some View {
        NavigationStack {
            List { WeightCalculatorSection(pendingSelection: $pendingWeightSelection) }
                .navigationTitle("一键配重")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var display: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            FoldedTrainingDisplay(reps: reps, note: $note, remainingSeconds: remaining(at: context.date), totalDuration: totalDuration, isPaused: pausedSeconds != nil)
        }
    }

    private var controls: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width - 16)
            let buttonSize = max(44, min(84, width / 3 - 8, geometry.size.height * 0.23))
            let availableHeight = max(0, geometry.size.height - buttonSize - 22)
            let scale = controlContentHeight > 0 ? min(1, availableHeight / controlContentHeight) : 1
            VStack(spacing: 6) {
                controlContent
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: width / max(scale, 0.01), alignment: .topLeading)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: ControlContentHeightKey.self, value: proxy.size.height)
                    })
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: width, height: availableHeight, alignment: .topLeading)
                HStack(spacing: 0) {
                    roundAction("清空配重", symbol: "trash", color: .red, size: max(44, buttonSize * 0.78)) {
                        TrainingFeedback.tap(); store.selected.removeAll()
                    }
                    .frame(maxWidth: .infinity)
                    roundAction("记录这一组", symbol: "checkmark", color: .green, size: buttonSize) {
                        customActionFocused = false
                        TrainingFeedback.confirm(); record()
                    }
                    .frame(maxWidth: .infinity)
                    roundAction("复用上一组", symbol: "arrow.clockwise", color: .yellow, size: max(44, buttonSize * 0.78), disabled: store.sets.isEmpty) {
                        TrainingFeedback.confirm(); reuse()
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: buttonSize)
            }
            .padding(8)
            .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 17))
            .foregroundStyle(.white)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .onPreferenceChange(ControlContentHeightKey.self) { controlContentHeight = $0 }
            .disabled(showCustomActionEditor)
        }
        .background(ControllerPanelBackground().ignoresSafeArea(.container, edges: .bottom))
        .overlay(alignment: .top) {
            if showCustomActionEditor { customActionEditor }
        }
    }

    private var customActionEditor: some View {
        HStack(spacing: 8) {
            Button("取消") {
                TrainingFeedback.tap()
                customActionFocused = false
                showCustomActionEditor = false
            }
            TextField("输入动作名称", text: $customActionDraft)
                .focused($customActionFocused)
                .submitLabel(.done)
                .onSubmit { saveCustomAction() }
                .textInputAutocapitalization(.never)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            Button("完成") { saveCustomAction() }
        }
        .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 17))
        .foregroundStyle(.white)
        .padding(8)
        .background(Color(red: 0.10, green: 0.04, blue: 0.16).opacity(0.97), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple, lineWidth: 1))
        .padding(8)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if showCustomActionEditor { customActionFocused = true }
            }
        }
    }

    private func roundAction(_ title: String, symbol: String, color: Color, size: CGFloat,
                             disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: size * 0.25, weight: .bold))
                Text(title).font(.custom("ZCOOLQingKeHuangYou-Regular", size: max(10, size * 0.16)))
                    .lineLimit(1).minimumScaleFactor(0.65)
            }
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.opacity(0.32), in: Circle())
            .overlay(Circle().stroke(color.opacity(0.9), lineWidth: 2))
            .shadow(color: color.opacity(0.4), radius: 5)
            .contentShape(Circle())
        }
        .buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.45 : 1)
        .accessibilityLabel(title)
    }

    private var controlContent: some View {
        VStack(spacing: 6) {
            consoleHeader
            HStack(spacing: 6) {
                TrainingPlanControls(note: $note, reps: $reps, compact: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                compactRepsControl
            }.metalPanel()
            HStack(spacing: 8) {
                Text("自定义动作").font(.custom("ZCOOLQingKeHuangYou-Regular", size: 14))
                Button {
                    TrainingFeedback.tap()
                    customActionDraft = note
                    showCustomActionEditor = true
                } label: {
                    HStack {
                        Text(note.isEmpty ? "输入动作名称" : note)
                            .foregroundStyle(note.isEmpty ? Color.white.opacity(0.6) : .white)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "pencil")
                    }
                    .padding(.horizontal, 8).frame(minHeight: 36)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("自定义动作名称")
            }.metalPanel()
            HStack(spacing: 8) {
                totalWeight
                ActionProgressView(action: note, compact: true)
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                WeightStepControls(compact: true)
            }.metalPanel()
            if sortedPlates.isEmpty {
                Text("还没有杠铃片规格，请在完整功能中添加。")
                    .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 12)).foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading).metalPanel()
            } else if let plate = selectedPlate {
                HStack(spacing: 4) {
                    plateSelector.frame(maxWidth: .infinity)
                    VStack(spacing: 0) {
                        ArcadeAdjustButton(symbol: "plus", label: "增加一对 \(plate.label)", disabled: !store.canAddPlate(plate)) {
                            store.addPlate(plate)
                        }
                        ArcadeAdjustButton(symbol: "minus", label: "减少一对 \(plate.label)", disabled: store.selected[plate.id, default: 0] == 0) {
                            store.selected[plate.id, default: 0] -= 1
                        }
                    }
                }
            }
        }
    }

    private var consoleHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                headerLeading
                restMenu
                headerButtons
            }
            VStack(spacing: 8) {
                HStack { headerLeading; restMenu }
                HStack { Spacer(); headerButtons }
            }
        }
    }

    @ViewBuilder
    private var headerLeading: some View {
        if deadline != nil || pausedSeconds != nil {
            HStack(spacing: 4) {
                Button(pausedSeconds == nil ? "暂停" : "继续") { TrainingFeedback.tap(); togglePause() }
                Button("+30 秒") { TrainingFeedback.adjust(); addTime() }
                Button("结束休息") { TrainingFeedback.tap(); deadline = nil; pausedSeconds = nil }
            }
            .buttonStyle(ConsoleHeaderButtonStyle())
            .frame(maxWidth: .infinity)
        } else {
            consoleTitle.frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var consoleTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("训练控制台").font(.custom("ZCOOLQingKeHuangYou-Regular", size: 20))
            Rectangle().fill(LinearGradient(colors: [.purple, .purple.opacity(0)], startPoint: .leading, endPoint: .trailing)).frame(height: 2)
        }
    }

    private var headerButtons: some View {
        HStack(spacing: 6) {
            Button("完整功能") { TrainingFeedback.tap(); showWeightCalculator = false; showFullLayout = true }.buttonStyle(ConsoleHeaderButtonStyle())
            Button("一键配重") { TrainingFeedback.tap(); pendingWeightSelection = nil; showFullLayout = false; showWeightCalculator = true }.buttonStyle(ConsoleHeaderButtonStyle())
        }
        .fixedSize()
    }

    private var restMenu: some View {
        Menu {
            Button("60 秒") { TrainingFeedback.tap(); duration = 60 }
            Button("90 秒") { TrainingFeedback.tap(); duration = 90 }
            Button("2 分钟") { TrainingFeedback.tap(); duration = 120 }
            Button("3 分钟") { TrainingFeedback.tap(); duration = 180 }
        } label: {
            LCDDisplay(value: String(format: "%02d:%02d", duration / 60, duration % 60), unit: "REST")
        }
        .accessibilityLabel("休息时长，\(duration) 秒")
        .accessibilityHint("选择休息时长")
    }

    private var totalWeight: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text("当前总重量").font(.custom("ZCOOLQingKeHuangYou-Regular", size: 15))
            Text(store.total.formattedWeight).font(.custom("Orbitron-Regular", size: 32).weight(.black))
                .foregroundStyle(Color(red: 0.72, green: 1, blue: 0.15))
                .lineLimit(1).minimumScaleFactor(0.55)
            Text("kg").font(.custom("Orbitron-Regular", size: 12).weight(.bold)).foregroundStyle(Color(red: 0.72, green: 1, blue: 0.15))
            Spacer(minLength: 0)
        }
    }

    private var compactRepsControl: some View {
        HStack(spacing: 2) {
            Text("每组次数").lineLimit(1).minimumScaleFactor(0.7)
            ArcadeAdjustButton(symbol: "minus", label: "减少每组次数", disabled: reps <= 1, showArithmeticSymbol: true) { reps -= 1 }
            Text("\(reps)").monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            ArcadeAdjustButton(symbol: "plus", label: "增加每组次数", disabled: reps >= 999, showArithmeticSymbol: true) { reps += 1 }
        }.buttonStyle(.plain).fixedSize(horizontal: true, vertical: false)
    }

    private var plateSelector: some View {
        GeometryReader { geometry in
        let cardWidth = max(80, (geometry.size.width - 12 - CGFloat(max(sortedPlates.count - 1, 0)) * 8) / CGFloat(max(sortedPlates.count, 1)))
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sortedPlates) { plate in
                    Button { TrainingFeedback.tap(); selectedPlateID = plate.id } label: {
                        VStack(spacing: 2) {
                            PlateEmblem(color: Color(hex: plate.colorHex)).frame(width: 28, height: 28)
                            Text(plate.label).font(.custom("Orbitron-Regular", size: 11))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text("\(store.selected[plate.id, default: 0]) 对").font(.custom("ZCOOLQingKeHuangYou-Regular", size: 12))
                        }
                        .frame(width: cardWidth, height: 76)
                        .background(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedPlate?.id == plate.id ? Color(red: 0.72, green: 1, blue: 0.15) : Color.white.opacity(0.3), lineWidth: selectedPlate?.id == plate.id ? 2.5 : 1))
                        .overlay(alignment: .topTrailing) {
                            if selectedPlate?.id == plate.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(red: 0.72, green: 1, blue: 0.15))
                                    .padding(4)
                                    .accessibilityHidden(true)
                            }
                        }
                        .shadow(color: selectedPlate?.id == plate.id ? Color.green.opacity(0.45) : .black.opacity(0.7), radius: 4, y: 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(plate.label)，\(store.selected[plate.id, default: 0]) 对\(selectedPlate?.id == plate.id ? "，已选择" : "")")
                }
            }
            .padding(6)
        }
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(height: 88)
    }

    private func saveCustomAction() {
        TrainingFeedback.confirm()
        note = customActionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        store.rememberCustomAction(note)
        customActionFocused = false
        showCustomActionEditor = false
    }

    private var sortedPlates: [Plate] {
        store.plates.sorted { $0.kilograms > $1.kilograms }
    }

    private var selectedPlate: Plate? {
        sortedPlates.first { $0.id == selectedPlateID } ?? sortedPlates.first
    }

    private func remaining(at date: Date) -> Int? {
        pausedSeconds ?? deadline.map { max(0, Int(ceil($0.timeIntervalSince(date)))) }
    }

    private func togglePause() {
        if let seconds = pausedSeconds {
            deadline = Date().addingTimeInterval(Double(seconds))
            pausedSeconds = nil
        } else if let seconds = remaining(at: Date()) {
            pausedSeconds = seconds
            deadline = nil
        }
    }

    private func addTime() {
        if let seconds = pausedSeconds {
            pausedSeconds = seconds + 30
            totalDuration += 30
        } else if let deadline = deadline {
            self.deadline = max(deadline, Date()).addingTimeInterval(30)
            totalDuration += 30
        }
    }
}

private struct ControlContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private extension View {
    func metalPanel() -> some View {
        self.padding(9)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color(white: 0.23), Color(white: 0.07), Color(white: 0.13)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 8).inset(by: 3).stroke(Color.black.opacity(0.7), lineWidth: 1))
                    .shadow(color: .black.opacity(0.8), radius: 3, y: 3)
            }
    }
}

private struct LCDDisplay: View {
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 2) {
                ForEach(Array(value.enumerated()), id: \.offset) { _, character in
                    if character == ":" {
                        VStack(spacing: 5) {
                            Circle().frame(width: 3, height: 3)
                            Circle().frame(width: 3, height: 3)
                        }
                    } else {
                        LCDDigit(character: character)
                    }
                }
            }
            .foregroundStyle(Color(red: 0.75, green: 1, blue: 0.22))
            .shadow(color: .green.opacity(0.5), radius: 3)
            Text(unit).font(.custom("Orbitron-Regular", size: 10).weight(.bold))
                .foregroundStyle(Color(red: 0.58, green: 0.72, blue: 0.54))
        }
        .frame(width: 110, height: 40)
        .background {
            Image("ArcadeLCDMaterial").resizable()
                .frame(width: 110, height: 40)
                .scaleEffect(1.12)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.65), radius: 2, y: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(unit)")
    }
}

private struct LCDDigit: View {
    let character: Character
    private let segments: [Character: String] = [
        "0": "abcdef", "1": "bc", "2": "abged",
        "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgecd", "7": "abc",
        "8": "abcdefg", "9": "abfgcd"
    ]

    var body: some View {
        let active = segments[character] ?? ""
        return ZStack {
            segment("a", active: active).frame(width: 9, height: 2).offset(y: -10)
            segment("g", active: active).frame(width: 9, height: 2)
            segment("d", active: active).frame(width: 9, height: 2).offset(y: 10)
            segment("f", active: active).frame(width: 2, height: 8).offset(x: -5, y: -5)
            segment("b", active: active).frame(width: 2, height: 8).offset(x: 5, y: -5)
            segment("e", active: active).frame(width: 2, height: 8).offset(x: -5, y: 5)
            segment("c", active: active).frame(width: 2, height: 8).offset(x: 5, y: 5)
        }
        .frame(width: 12, height: 22)
    }

    private func segment(_ name: Character, active: String) -> some View {
        RoundedRectangle(cornerRadius: 1).opacity(active.contains(name) ? 1 : 0.10)
    }
}

private struct FoldHinge: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [.black, Color(white: 0.27), Color(white: 0.10), .black],
                               startPoint: .top, endPoint: .bottom)
                HStack(spacing: 0) {
                    hingeCap
                    hingeBar
                    hingeCap
                }
                .padding(.horizontal, geometry.size.width * 0.04)
                .padding(.vertical, min(geometry.size.height * 0.18, 5))
                Rectangle().fill(Color.white.opacity(0.14))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
                Rectangle().fill(Color.black.opacity(0.8))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .clipped()
        }
        .allowsHitTesting(false)
    }

    private var hingeBar: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(LinearGradient(colors: [Color(white: 0.13), Color(white: 0.39), Color(white: 0.19), Color(white: 0.06)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }

    private var hingeCap: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
            .frame(width: 18)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.8), lineWidth: 1))
    }
}


struct ArcadeAdjustButton: View {
    let symbol: String
    let label: String
    var disabled = false
    var playsSound = true
    var showArithmeticSymbol = false
    let action: () -> Void

    var body: some View {
        if #available(iOS 17.0, *) {
            button.buttonRepeatBehavior(.enabled)
        } else {
            button
        }
    }

    private var button: some View {
        Button {
            if playsSound { TrainingFeedback.adjust() }
            else { TrainingFeedback.adjustHaptic() }
            action()
        } label: {
            Image(systemName: showArithmeticSymbol ? symbol : (symbol == "plus" ? "arrow.up" : "arrow.down"))
                .font(.system(size: 18, weight: .black))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ArcadeControlStyle(isIncrease: symbol == "plus"))
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}

private struct ControllerPanelBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("ArcadePanelMaterial").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                RoundedRectangle(cornerRadius: 36)
                    .stroke(Color.white.opacity(0.12), lineWidth: 2)
                    .padding(8)
                Color.black.opacity(0.25)
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }

}
