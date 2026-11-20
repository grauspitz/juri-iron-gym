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
    @State private var controlContentHeight: CGFloat = 0
    @State private var menuConfirmRequest = 0
    @State private var menuHint: String?
    @FocusState private var customActionFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var sceneVisible = false
    @State private var hudVisible = false
    @State private var controlsVisible = false
    @State private var energyVisible = false
    @State private var screenPowered = false
    @State private var bootVisible = true
    @State private var bootStarted = Date()
    @State private var shutdownStarted = Date()
    @State private var shutdownStage = 0
    @AppStorage("trainingStartupSound") private var trainingStartupSound = true
    let fold: CGRect
    let height: CGFloat
    let width: CGFloat
    let isLandscape: Bool
    let leadingInset: CGFloat
    let trailingInset: CGFloat
    let bottomInset: CGFloat
    @Binding var reps: Int
    @Binding var note: String
    @Binding var deadline: Date?
    @Binding var pausedSeconds: Int?
    @Binding var duration: Int
    @Binding var totalDuration: Int
    @Binding var showFullLayout: Bool
    @Binding var menuFocus: Int
    @Binding var selectedPlateID: UUID?
    @Binding var showWeightCalculator: Bool
    @Binding var pendingWeightSelection: [UUID: Int]?
    @Binding var showCustomActionEditor: Bool
    @Binding var customActionDraft: String
    let fullLayout: AnyView
    let menuBack: () -> Void
    let menuConfirm: () -> Bool
    let record: () -> Void
    let reuse: () -> Void
    let exit: () -> Void
    let fullStartup: Bool
    let isExiting: Bool

    private var isCompactPortrait: Bool {
        horizontalSizeClass == .compact && !isLandscape
    }

    private var usesWeightSheet: Bool { isCompactPortrait || isLandscape }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if isLandscape { speaker }
                Group {
                if showFullLayout {
                    fullLayout
                } else if showWeightCalculator {
                    GeometryReader { screen in
                        HandheldWeightSettings(confirmRequest: menuConfirmRequest) { showWeightCalculator = false; pendingWeightSelection = nil }
                            .environment(\.handheldControls, false)
                            .frame(width: screen.size.width, height: screen.size.height)
                            .clipped()
                    }
                } else {
                    display
                }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if isLandscape { speaker }
            }
                .frame(maxWidth: .infinity)
                .frame(height: max(0, fold.minY))
                .clipped()
                .overlay { if showCustomActionEditor { customActionEditor } }
        .scaleEffect(x: 1, y: reduceMotion || (screenPowered && !isExiting) ? 1 : 0.006, anchor: .center)
        .opacity(reduceMotion || screenPowered ? 1 : 0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5).delay(isExiting ? 2.4 : 0), value: screenPowered && !isExiting)
        .overlay {
            GeometryReader { geometry in
                Capsule()
                    .fill(LinearGradient(colors: [.clear, .purple, .white, .purple, .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * (energyVisible && !isExiting ? 0.95 : 0.02), height: 3)
                    .shadow(color: .purple, radius: 12)
                    .shadow(color: .pink, radius: 22)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .opacity(reduceMotion ? 0 : (isExiting ? 1 : (hudVisible ? 0 : 1)))
                    .animation(reduceMotion ? nil : .easeInOut(duration: isExiting ? 0.6 : 0.35), value: energyVisible && !isExiting)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: hudVisible)
            }.allowsHitTesting(false)
        }
                .overlay {
                    if !reduceMotion && isExiting {
                        TrainingShutdownScreen(started: shutdownStarted)
                            .allowsHitTesting(false)
                    } else if !reduceMotion && bootVisible {
                        TrainingBootScreen(started: bootStarted, duration: fullStartup ? 4.5 : 1.2, isShutdown: false)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
                .clipped()
            FoldHinge().frame(height: max(0, fold.height))
                .accessibilityHidden(true)
            controls
                .padding(.horizontal, isCompactPortrait ? 0 : (isLandscape ? max(leadingInset, trailingInset, 24) : max(leadingInset, trailingInset)))
                .padding(.bottom, bottomInset)
                .background {
                    ControllerPanelBackground(isHandheld: true)
                }
                .overlay { Color.black.opacity(shutdownStage >= 4 ? 0.94 : 0).allowsHitTesting(false) }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: shutdownStage >= 4)
                .opacity(controlsVisible ? 1 : 0)
                .offset(y: controlsVisible ? 0 : 20)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: controlsVisible)
                .frame(maxWidth: .infinity)
                .frame(height: max(0, height - fold.maxY))
        }
        .background {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        Image(isLandscape ? "ArcadePanelMaterial" : FoldedTrainingDisplay.backgroundImageName(note: note, isResting: (remaining(at: context.date) ?? 0) > 0))
                            .resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: max(0, fold.minY))
                            .clipped()
                            .opacity(sceneVisible && !isExiting ? 1 : 0)
                        Color.black.frame(height: max(0, fold.height))
                        ControllerPanelBackground(isHandheld: true)
                            .frame(height: max(0, height - fold.maxY))
                            .opacity(controlsVisible && shutdownStage < 4 ? 1 : 0)
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: sceneVisible && !isExiting)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: controlsVisible)
                }
            }
            .ignoresSafeArea(.container, edges: .horizontal)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    var body: some View {
        Group {
            if isLandscape { landscapeLayout } else { portraitLayout }
        }
        .environment(\.handheldControls, true)
        .environment(\.trainingModeUI, true)
        .environment(\.trainingLandscape, isLandscape)
        .allowsHitTesting(hudVisible && !bootVisible && !isExiting)
        .task { await startAnimation() }
        .task(id: isExiting) { await updateShutdownSequence() }
        .onChange(of: isExiting) { exiting in
            if exiting { shutdownStarted = Date() }
        }
        .onAppear {
            if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                note = "硬拉"
            }
        }
    }

    private var landscapeLayout: some View {
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

    private var landscapeScreen: some View {
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
            } else {
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
            } else if !reduceMotion && bootVisible {
                TrainingBootScreen(started: bootStarted, duration: fullStartup ? 4.5 : 1.2, isShutdown: false)
                    .allowsHitTesting(false)
            }
        }
        .opacity(reduceMotion || screenPowered ? 1 : 0)
        .clipped()
    }

    private func switchGrip(isLeft: Bool) -> some View {
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
        .opacity(controlsVisible && !isExiting ? 1 : 0)
    }

    private func controllerKey(_ title: String, label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
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

    private func joystick(size: CGFloat, color: Color, label: String, action: @escaping () -> Void) -> some View {
        GripJoystick(size: size, color: color, label: label, action: action) { translation in
            let x = translation.width, y = translation.height
            if showFullLayout {
                let direction = abs(y) >= abs(x) ? (y > 0 ? 1 : -1) : (x > 0 ? 1 : -1)
                menuFocus = menuFocus < 0 ? 0 : (menuFocus + direction + 3) % 3
                TrainingFeedback.adjustHaptic()
            }
        }
    }

    private func selectAdjacentAction(_ offset: Int) {
        let actions = TrainingStore.standardActions + store.customActions
        guard !actions.isEmpty else { return }
        let current = actions.firstIndex(where: { TrainingStore.actionKey($0) == TrainingStore.actionKey(note) }) ?? 0
        note = actions[(current + offset + actions.count) % actions.count]
        TrainingFeedback.tap()
    }

    private func closeScreenMenu() {
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

    private func confirmScreenMenu() {
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

    private func gripMaterial(isLeft: Bool) -> some View {
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

    private func gripAccent(isLeft: Bool) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [.white.opacity(0.35), .clear, .black.opacity(0.35)], startPoint: .leading, endPoint: .trailing))
            .background(isLeft ? Color(red: 0.94, green: 0.28, blue: 0.61) : Color(red: 0.25, green: 0.88, blue: 0.78))
            .overlay(alignment: isLeft ? .leading : .trailing) {
                Rectangle().fill(Color.black.opacity(0.6)).frame(width: 1)
            }
            .frame(width: 8)
    }

    private func gripButton(_ title: String, symbol: String, vertical: Bool = false, height: CGFloat = 44, disabled: Bool = false, action: @escaping () -> Void) -> some View {
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

    @MainActor private func startAnimation() async {
        if reduceMotion {
            screenPowered = true
            sceneVisible = true
            hudVisible = true
            controlsVisible = true
            bootVisible = false
            return
        }
        do {
            bootStarted = Date()
            controlsVisible = true
            energyVisible = true
            if trainingStartupSound { TrainingSound.adjust() }
            try await Task.sleep(nanoseconds: fullStartup ? 500_000_000 : 150_000_000)
            screenPowered = true
            if fullStartup {
                try await Task.sleep(nanoseconds: 700_000_000)
                if trainingStartupSound { TrainingSound.tap() }
                try await Task.sleep(nanoseconds: 2_600_000_000)
            } else {
                try await Task.sleep(nanoseconds: 650_000_000)
            }
            sceneVisible = true
            hudVisible = true
            if trainingStartupSound { TrainingSound.confirm() }
            try await Task.sleep(nanoseconds: fullStartup ? 700_000_000 : 400_000_000)
            withAnimation(.easeOut(duration: 0.2)) { bootVisible = false }
        } catch { return }
    }

    @MainActor private func updateShutdownSequence() async {
        shutdownStage = 0
        guard isExiting else { return }
        for stage in 1...4 {
            do { try await Task.sleep(nanoseconds: 150_000_000) } catch { return }
            shutdownStage = stage
        }
    }

    private func ambientLight(isSide: Bool) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: reduceMotion || scenePhase != .active || !sceneVisible || isExiting)) { context in
            let phase = reduceMotion ? 0.0 : sin(context.date.timeIntervalSinceReferenceDate * 0.45)
            GeometryReader { geometry in
                Ellipse()
                    .fill(LinearGradient(colors: [.cyan.opacity(0.22), .purple.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: geometry.size.width * (isSide ? 1.4 : 0.75), height: geometry.size.height * 0.6)
                    .blur(radius: 24)
                    .rotationEffect(.degrees(-25))
                    .position(x: geometry.size.width * (0.5 + 0.10 * phase), y: geometry.size.height * (isSide ? 0.38 : 0.12))
            }
            .opacity(sceneVisible && !isExiting ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var panelReflection: some View {
        GeometryReader { geometry in
            Image(FoldedTrainingDisplay.backgroundImageName(note: note, isResting: (remaining(at: Date()) ?? 0) > 0))
                .resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(x: 1, y: -1)
                .blur(radius: 18)
                .opacity(sceneVisible && !isExiting ? 0.10 : 0)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
                .clipped()
                .overlay {
                    LinearGradient(colors: [.purple.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                        .opacity(sceneVisible && !isExiting ? 1 : 0)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: sceneVisible && !isExiting)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var speaker: some View {
        let pictureWidth = min(width, max(0, fold.minY) * (1491.0 / 1055.0))
        return ArcadeSpeakerPanel()
            .frame(width: max(0, (width - pictureWidth) / 2))
            .accessibilityHidden(true)
            .allowsHitTesting(false)
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
            FoldedTrainingDisplay(reps: reps, note: $note, remainingSeconds: remaining(at: context.date), totalDuration: totalDuration, isPaused: pausedSeconds != nil, showEntireScene: isLandscape, sceneVisible: sceneVisible && !isExiting, hudVisible: hudVisible && !isExiting)
        }
    }

    private var controls: some View {
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

    private var customActionEditor: some View {
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

    private func roundAction(_ title: String, symbol: String, color: Color, size: CGFloat,
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

    private var controlContent: some View {
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

    private var consoleHeader: some View {
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

    private var headerButtons: some View {
        HStack(spacing: 6) {
            Button("完整功能") { TrainingFeedback.tap(); showWeightCalculator = false; showFullLayout = true }.buttonStyle(ConsoleHeaderButtonStyle())
            Button(usesWeightSheet ? "配重设置" : "一键配重") { TrainingFeedback.tap(); pendingWeightSelection = nil; showFullLayout = false; showWeightCalculator = true }.buttonStyle(ConsoleHeaderButtonStyle())
            Button("退出模式", action: exit).buttonStyle(ConsoleHeaderButtonStyle())
        }
        .fixedSize()
    }

    private var restMenu: some View {
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
                    .fill(Color(red: 0.12, green: 0.09, blue: 0.09))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.65), lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 9).inset(by: 2).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
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
    var isHandheld = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isHandheld {
                    Color(red: 0.72, green: 0.055, blue: 0.075)
                    Canvas { context, size in
                        for index in 0..<6500 {
                            let seed = UInt64(index) &* 2_654_435_761 &+ 1_013_904_223
                            let mixed = (seed ^ (seed >> 13)) &* 2_246_822_519
                            let x = CGFloat(mixed % 10_007) / 10_007 * size.width
                            let y = CGFloat((mixed >> 16) % 10_009) / 10_009 * size.height
                            let dot = CGRect(x: x, y: y, width: index.isMultiple(of: 5) ? 1.2 : 0.7, height: 0.7)
                            context.fill(Path(ellipseIn: dot), with: .color(index.isMultiple(of: 2) ? .white.opacity(0.09) : .black.opacity(0.12)))
                        }
                    }
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.black.opacity(0.28), lineWidth: 1)
                        .padding(3)
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        .padding(5)
                    VStack {
                        HStack {
                            screw
                            Spacer()
                            screw
                        }
                        Spacer()
                        HStack {
                            screw
                            Spacer()
                            screw
                        }
                    }
                    .padding(10)
                    HStack(alignment: .bottom) {
                        HStack(spacing: 5) {
                            ForEach(0..<4, id: \.self) { _ in
                                Capsule().fill(Color.black.opacity(0.68))
                                    .frame(width: 4, height: 24)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                            }
                        }
                        .rotationEffect(.degrees(42))
                        .padding(.leading, 18)
                        .padding(.bottom, 20)
                        Spacer()
                        VStack(spacing: 0) {
                            Text("SUP").font(.system(size: 25, weight: .black, design: .rounded)).italic()
                            Rectangle().frame(width: 56, height: 4)
                            Rectangle().frame(width: 56, height: 2).padding(.top, 2)
                        }
                        .foregroundStyle(Color(red: 0.91, green: 0.88, blue: 0.83))
                        .rotationEffect(.degrees(-35))
                        .padding(.trailing, 8)
                        .padding(.bottom, 18)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                } else {
                    Image("ArcadePanelMaterial").resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    RoundedRectangle(cornerRadius: 36)
                        .stroke(Color.white.opacity(0.12), lineWidth: 2)
                        .padding(8)
                    Color.black.opacity(0.25)
                }
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private var screw: some View {
        Circle().fill(Color(red: 0.35, green: 0.055, blue: 0.06))
            .overlay(Capsule().fill(Color.black.opacity(0.5)).frame(width: 4, height: 1).rotationEffect(.degrees(-35)))
            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            .frame(width: 7, height: 7)
    }
}


private struct HandheldGripShape: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        let corners: UIRectCorner = isLeft ? [.topLeft, .bottomLeft] : [.topRight, .bottomRight]
        return Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: 24, height: 24)).cgPath)
    }
}

private struct GripJoystick: View {
    let size: CGFloat
    let color: Color
    let label: String
    let action: () -> Void
    let onDrag: (CGSize) -> Void
    @GestureState private var translation: CGSize = .zero

    var body: some View {
        ZStack {
            Circle().fill(Color.black).shadow(color: .black.opacity(0.8), radius: 4, y: 4)
            Circle().stroke(color.opacity(0.85), lineWidth: max(2, size * 0.06)).padding(size * 0.08)
            Circle().fill(LinearGradient(colors: [Color(white: 0.28), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(size * 0.18)
                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1).padding(size * 0.18))
                .offset(x: max(-size * 0.12, min(size * 0.12, translation.width)), y: max(-size * 0.12, min(size * 0.12, translation.height)))
        }
        .frame(width: size, height: size)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .updating($translation) { value, state, _ in state = value.translation }
            .onEnded { value in
                if max(abs(value.translation.width), abs(value.translation.height)) < 12 { action() }
                else { onDrag(value.translation) }
            })
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }
}

private struct GripPlasticButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        return configuration.label
            .foregroundStyle(Color(red: 0.23, green: 0.23, blue: 0.22))
            .background {
                shape.fill(Color(red: 0.24, green: 0.24, blue: 0.23))
                    .offset(y: 3)
                    .shadow(color: .black.opacity(0.55), radius: 2, y: 3)
                shape.fill(Color(red: 0.78, green: 0.77, blue: 0.74))
                    .overlay {
                        Canvas { context, size in
                            for index in 0..<500 {
                                let seed = UInt64(index) &* 2_654_435_761 &+ 1_013_904_223
                                let x = CGFloat(seed % 10_007) / 10_007 * size.width
                                let y = CGFloat((seed >> 16) % 10_009) / 10_009 * size.height
                                let grain = CGRect(x: x, y: y, width: 0.6, height: 0.6)
                                context.fill(Path(ellipseIn: grain), with: .color(index.isMultiple(of: 2) ? .white.opacity(0.10) : .black.opacity(0.08)))
                            }
                        }
                        .clipShape(shape)
                        .allowsHitTesting(false)
                    }
                    .overlay(shape.stroke(Color.black.opacity(0.18), lineWidth: 1))
                    .overlay(alignment: .top) {
                        shape.stroke(Color.white.opacity(0.23), lineWidth: 1).padding(1).mask(
                            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)
                        )
                    }
                    .offset(y: configuration.isPressed ? 2 : 0)
            }
            .offset(y: configuration.isPressed ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.6)
    }
}
