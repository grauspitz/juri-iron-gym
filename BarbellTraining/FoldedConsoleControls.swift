import SwiftUI
import UIKit

extension FoldedTrainingView {
    var controls: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width - 16)
            let buttonSize = max(44, min(isCompactPortrait ? 72 : 84, width / 3 - 8, geometry.size.height * 0.20))
            let availableHeight = max(0, geometry.size.height - buttonSize - 22)
            let scale = controlContentHeight > 0 ? min(1, availableHeight / controlContentHeight) : 1
            VStack(spacing: 6) {
                if usesWeightSheet {
                    ScrollView(.vertical, showsIndicators: false) {
                        controlContent
                            .frame(width: max(0, width - 16), alignment: .topLeading)
                            .padding(8)
                    }
                    .frame(width: width, height: availableHeight, alignment: .top)
                    .background(Color(red: 0.10, green: 0.075, blue: 0.075), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.65), lineWidth: 2))
                    .overlay(RoundedRectangle(cornerRadius: 12).inset(by: 2).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
                } else {
                    controlContent
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: width / max(scale, 0.01), alignment: .topLeading)
                        .background(GeometryReader { proxy in
                            Color.clear.preference(key: ControlContentHeightKey.self, value: proxy.size.height)
                        })
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: width, height: availableHeight, alignment: .topLeading)
                }
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
                .saturation(shutdownStage >= 3 ? 0 : 1)
                .brightness(shutdownStage >= 3 ? -0.32 : 0)
                .animation(.easeOut(duration: 0.18), value: shutdownStage >= 3)
            }
            .padding(8)
            .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 17))
            .foregroundStyle(.white)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .onPreferenceChange(ControlContentHeightKey.self) { controlContentHeight = $0 }
            .disabled(showCustomActionEditor)
        }

    }

    var customActionEditor: some View {
        HStack(spacing: 8) {
            Button("取消") {
                TrainingFeedback.tap()
                customActionFocused = false
                showCustomActionEditor = false
            }
            .buttonStyle(TrainingModalButtonStyle())
            TextField("输入动作名称", text: $customActionDraft)
                .focused($customActionFocused)
                .submitLabel(.done)
                .onSubmit { saveCustomAction() }
                .textInputAutocapitalization(.never)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            Button("确认") { saveCustomAction() }
                .buttonStyle(TrainingModalButtonStyle(confirm: true))
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

    func roundAction(_ title: String, symbol: String, color: Color, size: CGFloat,
                             disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: size * 0.25, weight: .bold))
                Text(title).font(.custom("ZCOOLQingKeHuangYou-Regular", size: max(10, size * 0.16)))
                    .lineLimit(1).minimumScaleFactor(0.65)
            }
            .foregroundStyle(Color(white: 0.16))
            .frame(width: size, height: size)
            .background {
                Circle().fill(Color(red: 0.34, green: 0.025, blue: 0.035))
                    .overlay(Circle().stroke(Color.black.opacity(0.65), lineWidth: 1.5))
                    .overlay(Circle().inset(by: 2).stroke(Color.white.opacity(0.16), lineWidth: 1))
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 4)
                Circle().fill(color)
                    .overlay(Circle().fill(RadialGradient(colors: [.white.opacity(0.32), .clear, .black.opacity(0.24)], center: .init(x: 0.35, y: 0.18), startRadius: 0, endRadius: size * 0.8)))
                    .overlay(Circle().stroke(Color.black.opacity(0.48), lineWidth: 1))
                    .overlay(Circle().inset(by: 2).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .padding(5)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 2)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.45 : 1)
        .accessibilityLabel(title)
    }

    var controlContent: some View {
        VStack(spacing: 6) {
            consoleHeader
                .padding(4)
                .background(Color(red: 0.88, green: 0.86, blue: 0.82), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.48, green: 0.35, blue: 0.33), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
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
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("自定义动作名称")
            }.metalPanel()
            HStack(spacing: 8) {
                totalWeight
                    .saturation(shutdownStage >= 2 ? 0 : 1)
                    .brightness(shutdownStage >= 2 ? -0.32 : 0)
                    .animation(.easeOut(duration: 0.18), value: shutdownStage >= 2)
                ActionProgressView(action: note, compact: true)
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                WeightStepControls(compact: true)
            }.metalPanel()
            if !usesWeightSheet && sortedPlates.isEmpty {
                Text("还没有杠铃片规格，请在完整功能中添加。")
                    .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 12)).foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading).metalPanel()
            } else if !usesWeightSheet, let plate = selectedPlate {
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

    var consoleHeader: some View {
        ViewThatFits(in: .horizontal) {
            if isCompactPortrait && deadline == nil && pausedSeconds == nil {
                HStack(spacing: 6) {
                    restMenu
                    Spacer(minLength: 0)
                    headerButtons
                }
            }
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
    var headerLeading: some View {
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

    var consoleTitle: some View {
        HStack(spacing: 5) {
            Text("训练控制台").font(.custom("ZCOOLQingKeHuangYou-Regular", size: 20))
                .lineLimit(1).minimumScaleFactor(0.6)
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(Color(red: 0.82, green: 0.12, blue: 0.13))
                        .frame(width: 5, height: 17).rotationEffect(.degrees(35))
                }
            }
        }
        .foregroundStyle(Color(red: 0.76, green: 0.06, blue: 0.08))
    }

    var headerButtons: some View {
        HStack(spacing: 6) {
            Button("完整功能") { TrainingFeedback.tap(); showWeightCalculator = false; showFullLayout = true }.buttonStyle(ConsoleHeaderButtonStyle())
            Button(usesWeightSheet ? "配重设置" : "一键配重") { TrainingFeedback.tap(); pendingWeightSelection = nil; showFullLayout = false; showWeightCalculator = true }.buttonStyle(ConsoleHeaderButtonStyle())
            Button("退出模式", action: exit).buttonStyle(ConsoleHeaderButtonStyle())
        }
        .fixedSize()
    }

    var restMenu: some View {
        Menu {
            if isLandscape && (deadline != nil || pausedSeconds != nil) {
                Button(pausedSeconds == nil ? "暂停休息" : "继续休息") { TrainingFeedback.tap(); togglePause() }
                Button("增加 30 秒") { TrainingFeedback.adjust(); addTime() }
                Button("结束休息") { TrainingFeedback.tap(); deadline = nil; pausedSeconds = nil }
                Divider()
            }
            Button("60 秒") { TrainingFeedback.tap(); duration = 60 }
            Button("90 秒") { TrainingFeedback.tap(); duration = 90 }
            Button("2 分钟") { TrainingFeedback.tap(); duration = 120 }
            Button("3 分钟") { TrainingFeedback.tap(); duration = 180 }
        } label: {
            LCDDisplay(value: String(format: "%02d:%02d", duration / 60, duration % 60), unit: "REST")
                .saturation(shutdownStage >= 1 ? 0 : 1)
                .brightness(shutdownStage >= 1 ? -0.32 : 0)
                .animation(.easeOut(duration: 0.18), value: shutdownStage >= 1)
        }
        .accessibilityLabel("休息时长，\(duration) 秒")
        .accessibilityHint("选择休息时长")
    }

    var totalWeight: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text("当前总重量").font(.custom("ZCOOLQingKeHuangYou-Regular", size: 15))
            Text(store.total.formattedWeight).font(.custom("Orbitron-Regular", size: 32).weight(.black))
                .foregroundStyle(Color(red: 0.72, green: 1, blue: 0.15))
                .lineLimit(1).minimumScaleFactor(0.55)
            Text("kg").font(.custom("Orbitron-Regular", size: 12).weight(.bold)).foregroundStyle(Color(red: 0.72, green: 1, blue: 0.15))
            Spacer(minLength: 0)
        }
    }

    var compactRepsControl: some View {
        HStack(spacing: 2) {
            Text("每组次数").lineLimit(1).minimumScaleFactor(0.7)
            ArcadeAdjustButton(symbol: "minus", label: "减少每组次数", disabled: reps <= 1, showArithmeticSymbol: true) { reps -= 1 }
            Text("\(reps)").monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            ArcadeAdjustButton(symbol: "plus", label: "增加每组次数", disabled: reps >= 999, showArithmeticSymbol: true) { reps += 1 }
        }.buttonStyle(.plain).fixedSize(horizontal: true, vertical: false)
    }

    var plateSelector: some View {
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
                        .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 8))
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

}
