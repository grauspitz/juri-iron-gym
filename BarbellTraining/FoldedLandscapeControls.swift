import SwiftUI
import UIKit

extension FoldedTrainingView {
    var landscapeLayout: some View {
        GeometryReader { geometry in
            let gripWidth = min(geometry.size.width * 0.23, max(125, geometry.size.width * 0.19))
            HStack(spacing: 0) {
                switchGrip(isLeft: true).frame(width: gripWidth).zIndex(1)
                landscapeScreen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .clipped()
                switchGrip(isLeft: false).frame(width: gripWidth).zIndex(1)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black)
        }
    }

    var landscapeScreen: some View {
        ZStack {
            Color.black
            if showFullLayout {
                fullLayout
            } else if showWeightCalculator {
                GeometryReader { screen in
                    HandheldWeightSettings(confirmRequest: menuConfirmRequest) { showWeightCalculator = false; pendingWeightSelection = nil }
                        .environment(\.handheldControls, false)
                        .frame(width: screen.size.width, height: screen.size.height)
                        .clipped()
                }
            } else if scenePrepared {
                display
            }
            if showCustomActionEditor { customActionEditor }
            if let hint = menuHint, showFullLayout {
                VStack {
                    Spacer()
                    Text(hint).font(.caption.weight(.semibold)).foregroundStyle(.white)
                        .padding(8).background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                        .padding(8)
                }
                .allowsHitTesting(false)
            }
            if !reduceMotion && isExiting {
                TrainingShutdownScreen(started: shutdownStarted).allowsHitTesting(false)
            } else if !reduceMotion && bootVisible && bootSequenceStarted {
                TrainingBootScreen(started: bootStarted, duration: fullStartup ? 4.5 : 1.2, isShutdown: false)
                    .allowsHitTesting(false)
            }
        }
        .opacity(reduceMotion || screenPowered ? 1 : 0)
        .clipped()
        .allowsHitTesting(hudVisible && !bootVisible && !isExiting)
    }

    func switchGrip(isLeft: Bool) -> some View {
        GeometryReader { geometry in
            let gap = max(3, min(12, geometry.size.height * 0.025))
            let rowHeight = max(44, min(66, geometry.size.height * 0.135))
            let keySize = max(28, min(44, geometry.size.height * 0.095))
            let stickSize = max(52, min(88, geometry.size.height * 0.18))
            VStack(spacing: max(2, gap * 0.55)) {
                Spacer(minLength: 0)
                if isLeft {
                    joystick(size: stickSize, color: .pink, label: "取消或返回") { closeScreenMenu() }
                    VStack(spacing: 0) {
                        controllerKey("▲", label: "增加每组次数", size: keySize) { if reps < 999 { reps += 1; TrainingFeedback.adjust() } }
                        HStack(spacing: keySize * 0.55) {
                            controllerKey("◀", label: "选择上一个动作", size: keySize) { selectAdjacentAction(-1) }
                            controllerKey("▶", label: "选择下一个动作", size: keySize) { selectAdjacentAction(1) }
                        }
                        controllerKey("▼", label: "减少每组次数", size: keySize) { if reps > 1 { reps -= 1; TrainingFeedback.adjust() } }
                    }
                    controllerKey("−", label: "返回", size: keySize) { closeScreenMenu() }
                    restMenu.scaleEffect(min(1, geometry.size.width / 140))
                        .frame(height: max(34, keySize))
                    gripButton("自定义动作", symbol: "pencil") {
                        customActionDraft = note; showCustomActionEditor = true
                    }
                } else {
                    VStack(spacing: 0) {
                        controllerKey("Y", label: "完整功能", size: keySize) { showWeightCalculator = false; showFullLayout = true }
                        HStack(spacing: keySize * 0.55) {
                            controllerKey("X", label: "配重设置", size: keySize) { showFullLayout = false; showWeightCalculator = true }
                            controllerKey("B", label: "返回", size: keySize) { closeScreenMenu() }
                        }
                        controllerKey("A", label: "确认", size: keySize) { confirmScreenMenu() }
                    }
                    joystick(size: stickSize, color: .cyan, label: "确认选择") { confirmScreenMenu() }
                    gripButton("记录这一组", symbol: "checkmark") { TrainingFeedback.confirm(); record() }
                    HStack(spacing: gap) {
                        gripButton("复用上一组", symbol: "arrow.clockwise", vertical: true, height: rowHeight) { TrainingFeedback.confirm(); reuse() }
                        gripButton("清空配重", symbol: "trash", vertical: true, height: rowHeight) { TrainingFeedback.tap(); store.selected.removeAll() }
                    }
                    HStack(spacing: gap) {
                        gripButton("配重设置", symbol: "gearshape", vertical: true, height: rowHeight) { showFullLayout = false; showWeightCalculator = true }
                        gripButton("完整功能", symbol: "square.grid.2x2", vertical: true, height: rowHeight) { showWeightCalculator = false; showFullLayout = true }
                    }
                    gripButton("退出模式", symbol: "xmark", action: exit)
                }
                Spacer(minLength: 0)
            }
            .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, max(5, min(12, geometry.size.width * 0.05)))
            .padding(.vertical, 5)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background { gripMaterial(isLeft: isLeft) }
        }
        .onAppear {
            print("{\"training_start_event\":\"landscape_grip_appeared\",\"side\":\"\(isLeft ? "left" : "right")\",\"timestamp_ms\":\(Int(Date().timeIntervalSince1970 * 1000))}")
        }
        .opacity(controlsVisible ? 1 : 0)
        .overlay { Color.black.opacity(shutdownStage >= 4 ? 0.12 : 0).allowsHitTesting(false) }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: shutdownStage >= 4)
    }

    func controllerKey(_ title: String, label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: max(14, size * 0.48), weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: max(44, size), height: max(44, size))
                .background {
                    Circle().fill(LinearGradient(colors: [Color(white: 0.30), Color(white: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: size, height: size)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2).frame(width: size, height: size))
                        .shadow(color: .black.opacity(0.7), radius: 2, y: 3)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    func joystick(size: CGFloat, color: Color, label: String, action: @escaping () -> Void) -> some View {
        GripJoystick(size: size, color: color, label: label, action: action) { translation in
            let x = translation.width, y = translation.height
            if showFullLayout {
                let direction = abs(y) >= abs(x) ? (y > 0 ? 1 : -1) : (x > 0 ? 1 : -1)
                menuFocus = menuFocus < 0 ? 0 : (menuFocus + direction + 3) % 3
                TrainingFeedback.adjustHaptic()
            }
        }
    }

    func selectAdjacentAction(_ offset: Int) {
        let actions = TrainingStore.standardActions + store.customActions
        guard !actions.isEmpty else { return }
        let current = actions.firstIndex(where: { TrainingStore.actionKey($0) == TrainingStore.actionKey(note) }) ?? 0
        note = actions[(current + offset + actions.count) % actions.count]
        TrainingFeedback.tap()
    }

    func closeScreenMenu() {
        TrainingFeedback.tap()
        menuHint = nil
        if showCustomActionEditor {
            customActionFocused = false
            showCustomActionEditor = false
        } else if showWeightCalculator {
            pendingWeightSelection = nil
            showWeightCalculator = false
        } else if showFullLayout {
            menuBack()
        }
    }

    func confirmScreenMenu() {
        TrainingFeedback.tap()
        if showCustomActionEditor {
            saveCustomAction()
        } else if showWeightCalculator {
            menuConfirmRequest += 1
        } else if showFullLayout {
            if !menuConfirm() { menuHint = "请在屏幕中选择或填写内容" }
        } else {
            menuHint = "请选择屏幕中的操作"
        }
    }

    func gripMaterial(isLeft: Bool) -> some View {
        GeometryReader { geometry in
            let shape = HandheldGripShape(isLeft: isLeft)
            ZStack {
                shape.fill(LinearGradient(stops: [
                    .init(color: Color(white: 0.22), location: 0),
                    .init(color: Color(white: 0.13), location: 0.18),
                    .init(color: Color(white: 0.10), location: 0.65),
                    .init(color: Color(white: 0.045), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                Canvas { context, size in
                    for index in 0..<3200 {
                        let seed = UInt64(index) &* 2_654_435_761 &+ 1_013_904_223
                        let mixed = (seed ^ (seed >> 13)) &* 2_246_822_519
                        let x = CGFloat(mixed % 10_007) / 10_007 * size.width
                        let y = CGFloat((mixed >> 16) % 10_009) / 10_009 * size.height
                        let diameter: CGFloat = index.isMultiple(of: 7) ? 1.7 : 1.1
                        let point = CGRect(x: x, y: y, width: diameter, height: diameter)
                        let grain = index.isMultiple(of: 3) ? Color.white.opacity(0.20) : Color.black.opacity(0.25)
                        context.fill(Path(ellipseIn: point), with: .color(grain))
                    }
                }
                .allowsHitTesting(false)
                LinearGradient(colors: [Color(red: 0.44, green: 0.40, blue: 0.56).opacity(0.35), .clear, .black.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .allowsHitTesting(false)
                HStack(spacing: 0) {
                    if !isLeft { gripAccent(isLeft: isLeft) }
                    Spacer(minLength: 0)
                    if isLeft { gripAccent(isLeft: isLeft) }
                }
                .overlay {
                    LinearGradient(colors: [isLeft ? Color.pink.opacity(0.14) : Color.cyan.opacity(0.14), .clear], startPoint: isLeft ? .trailing : .leading, endPoint: isLeft ? .leading : .trailing)
                }
                shape.fill(LinearGradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
                ambientLight(isSide: true)
                shape.stroke(LinearGradient(colors: [.white.opacity(0.38), .clear, .black.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { index in
                            Capsule().fill((isLeft ? Color.pink : Color.cyan).opacity(0.12 + Double(index) * 0.015))
                                .frame(width: 2, height: 42)
                                .rotationEffect(.degrees(48))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: isLeft ? .leading : .trailing)
                    .padding(8)
                }
                .allowsHitTesting(false)
                ForEach(0..<14, id: \.self) { index in
                    let x = geometry.size.width * CGFloat((index * 37 % 83) + 8) / 100
                    let y = geometry.size.height * CGFloat((index * 53 % 89) + 5) / 100
                    Capsule().fill(index.isMultiple(of: 2) ? Color.white.opacity(0.11) : Color.black.opacity(0.12))
                        .frame(width: CGFloat(3 + index % 4), height: 1)
                        .rotationEffect(.degrees(-28))
                        .position(x: x, y: y)
                }
            }
            .clipShape(shape)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    func gripAccent(isLeft: Bool) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [.white.opacity(0.35), .clear, .black.opacity(0.35)], startPoint: .leading, endPoint: .trailing))
            .background(isLeft ? Color(red: 0.94, green: 0.28, blue: 0.61) : Color(red: 0.25, green: 0.88, blue: 0.78))
            .overlay(alignment: isLeft ? .leading : .trailing) {
                Rectangle().fill(Color.black.opacity(0.6)).frame(width: 1)
            }
            .frame(width: 8)
    }

    func gripButton(_ title: String, symbol: String, vertical: Bool = false, height: CGFloat = 44, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if vertical {
                    VStack(spacing: 3) {
                        Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                        Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                } else {
                    Label(title, systemImage: symbol)
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
        .buttonStyle(GripPlasticButtonStyle())
        .disabled(disabled)
    }

}
