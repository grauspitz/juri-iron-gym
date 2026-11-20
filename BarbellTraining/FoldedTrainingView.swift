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
    @EnvironmentObject var store: TrainingStore
    @State var controlContentHeight: CGFloat = 0
    @State var menuConfirmRequest = 0
    @State var menuHint: String?
    @FocusState var customActionFocused: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var sceneVisible = false
    @State var scenePrepared = false
    @State var hudVisible = false
    @State var controlsVisible = true
    @State var energyVisible = false
    @State var screenPowered = false
    @State var bootVisible = true
    @State var bootSequenceStarted = false
    @State var bootStarted = Date()
    @State var shutdownStarted = Date()
    @State var shutdownStage = 0
    @AppStorage("trainingStartupSound") var trainingStartupSound = true
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

    var isCompactPortrait: Bool {
        horizontalSizeClass == .compact && !isLandscape
    }

    var usesWeightSheet: Bool { isCompactPortrait || isLandscape }

    var portraitLayout: some View {
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
                } else if scenePrepared {
                    display
                } else {
                    Color.black
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
                    .opacity(reduceMotion ? 0 : (isExiting ? 1 : (energyVisible && !hudVisible ? 1 : 0)))
                    .animation(reduceMotion ? nil : .easeInOut(duration: isExiting ? 0.6 : 0.35), value: energyVisible && !isExiting)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: hudVisible)
            }.allowsHitTesting(false)
        }
                .overlay {
                    if !reduceMotion && isExiting {
                        TrainingShutdownScreen(started: shutdownStarted)
                            .allowsHitTesting(false)
                    } else if !reduceMotion && bootVisible && bootSequenceStarted {
                        TrainingBootScreen(started: bootStarted, duration: fullStartup ? 4.5 : 1.2, isShutdown: false)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
                .clipped()
                .allowsHitTesting(hudVisible && !bootVisible && !isExiting)
            FoldHinge().frame(height: max(0, fold.height))
                .accessibilityHidden(true)
            controls
                .padding(.horizontal, isCompactPortrait ? 0 : (isLandscape ? max(leadingInset, trailingInset, 24) : max(leadingInset, trailingInset)))
                .padding(.bottom, bottomInset)
                .background {
                    ControllerPanelBackground(isHandheld: true)
                }
                .overlay { Color.black.opacity(shutdownStage >= 4 ? 0.12 : 0).allowsHitTesting(false) }
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
                        Group {
                            if scenePrepared && !isExiting {
                                Image(FoldedTrainingDisplay.backgroundImageName(note: note, isResting: (remaining(at: context.date) ?? 0) > 0))
                                    .resizable().scaledToFill()
                                    .opacity(sceneVisible ? 1 : 0)
                            } else {
                                Color.black
                            }
                        }
                        .frame(width: geometry.size.width, height: max(0, fold.minY))
                        .clipped()
                        Color.black.frame(height: max(0, fold.height))
                        ControllerPanelBackground(isHandheld: true)
                            .frame(height: max(0, height - fold.maxY))
                            .opacity(controlsVisible ? 1 : 0)
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
        .allowsHitTesting(!isExiting)
        .task(id: isExiting) {
            if !isExiting { await startAnimation() }
        }
        .task(id: isExiting) { await updateShutdownSequence() }
        .onChange(of: isExiting) { exiting in
            if exiting { shutdownStarted = Date() }
        }
        .onAppear {
            print("{\"training_start_event\":\"view_appeared\",\"timestamp_ms\":\(Int(Date().timeIntervalSince1970 * 1000))}")
            if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                note = "硬拉"
            }
        }
    }

    @MainActor func startAnimation() async {
        if reduceMotion {
            scenePrepared = true
            screenPowered = true
            sceneVisible = true
            hudVisible = true
            controlsVisible = true
            bootVisible = false
            return
        }
        do {
            try await Task.sleep(nanoseconds: 350_000_000)
            bootStarted = Date()
            bootSequenceStarted = true
            energyVisible = true
            if trainingStartupSound { TrainingSound.adjust() }
            try await Task.sleep(nanoseconds: 100_000_000)
            print("{\"training_start_event\":\"load_scene\",\"timestamp_ms\":\(Int(Date().timeIntervalSince1970 * 1000))}")
            scenePrepared = true
            try await Task.sleep(nanoseconds: fullStartup ? 400_000_000 : 50_000_000)
            screenPowered = true
            if fullStartup {
                try await Task.sleep(nanoseconds: 700_000_000)
                if trainingStartupSound { TrainingSound.tap() }
                try await Task.sleep(nanoseconds: 2_600_000_000)
            } else {
                try await Task.sleep(nanoseconds: 650_000_000)
            }
            print("{\"training_start_event\":\"show_scene\",\"timestamp_ms\":\(Int(Date().timeIntervalSince1970 * 1000))}")
            sceneVisible = true
            hudVisible = true
            if trainingStartupSound { TrainingSound.confirm() }
            try await Task.sleep(nanoseconds: fullStartup ? 700_000_000 : 400_000_000)
            withAnimation(.easeOut(duration: 0.2)) { bootVisible = false }
        } catch { return }
    }

    @MainActor func updateShutdownSequence() async {
        shutdownStage = 0
        guard isExiting else { return }
        for stage in 1...4 {
            do { try await Task.sleep(nanoseconds: 150_000_000) } catch { return }
            shutdownStage = stage
        }
    }

    func ambientLight(isSide: Bool) -> some View {
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

    var panelReflection: some View {
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

    var speaker: some View {
        let pictureWidth = min(width, max(0, fold.minY) * (1491.0 / 1055.0))
        return ArcadeSpeakerPanel()
            .frame(width: max(0, (width - pictureWidth) / 2))
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    var weightCalculator: some View {
        NavigationStack {
            List { WeightCalculatorSection(pendingSelection: $pendingWeightSelection) }
                .navigationTitle("一键配重")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    var display: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            FoldedTrainingDisplay(reps: reps, note: $note, remainingSeconds: remaining(at: context.date), totalDuration: totalDuration, isPaused: pausedSeconds != nil, showEntireScene: isLandscape, sceneVisible: sceneVisible && !isExiting, hudVisible: hudVisible && !isExiting)
        }
    }

    func saveCustomAction() {
        TrainingFeedback.confirm()
        note = customActionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        store.rememberCustomAction(note)
        customActionFocused = false
        showCustomActionEditor = false
    }

    var sortedPlates: [Plate] {
        store.plates.sorted { $0.kilograms > $1.kilograms }
    }

    var selectedPlate: Plate? {
        sortedPlates.first { $0.id == selectedPlateID } ?? sortedPlates.first
    }

    func remaining(at date: Date) -> Int? {
        pausedSeconds ?? deadline.map { max(0, Int(ceil($0.timeIntervalSince(date)))) }
    }

    func togglePause() {
        if let seconds = pausedSeconds {
            deadline = Date().addingTimeInterval(Double(seconds))
            pausedSeconds = nil
        } else if let seconds = remaining(at: Date()) {
            pausedSeconds = seconds
            deadline = nil
        }
    }

    func addTime() {
        if let seconds = pausedSeconds {
            pausedSeconds = seconds + 30
            totalDuration += 30
        } else if let deadline = deadline {
            self.deadline = max(deadline, Date()).addingTimeInterval(30)
            totalDuration += 30
        }
    }
}
