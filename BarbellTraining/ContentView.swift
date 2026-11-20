import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var store: TrainingStore
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @StateObject var advice = TrainingAdvice()
    @StateObject var shortcuts = TrainingShortcuts.shared
    @State var shortcutShareImage: SharedTrainingImage?
    @State var shortcutShareError: String?
    @AppStorage("energyBodyWeight") var energyBodyWeight = ""
    @State var reps = 10
    @State var showRecordForm = false
    @State var showStartRequired = false
    @State var showFinishAfterVictory = false
    @State var celebratingPlanID: UUID?
    @State var recordAction = ""
    @State var recordReps = 10
    @State var restDeadline: Date?
    @State var restDuration = 90
    @State var restTotalDuration = 90
    @State var pausedRestSeconds: Int?
    @State var showFullLayout = false
    @State var arcadeMenuFocus = -1
    @State var isTrainingLandscape = false
    @State var calendarDate = Date()
    @State var trainingModeAnchor: CGRect?
    @State var selectedFoldedPlateID: UUID?
    @State var showFoldedWeightCalculator = false
    @State var pendingFoldedWeightSelection: [UUID: Int]?
    @State var showFoldedCustomActionEditor = false
    @State var foldedCustomActionDraft = ""
    @State var isHorizontalFolded = false
    @State var isTrainingMode = false
    @State var trainingModeManuallyOpened = false
    @State var hasStartedTrainingMode = false
    @State var fullTrainingStartup = false
    @State var isTrainingModeExiting = false
    @State var trainingExitTask: Task<Void, Never>?
    @State var showAdd = false
    @State var showHistory = false
    @State var showOverview = false
    @State var selectedInnerTab = 0
    @State var showTools = false
    @State var showCalculator = false
    @State var editingPlate: Plate?
    @State var note = ""
    @State var showBarSettings = false
    @State var editingTodaySet: TrainingSet?
    @State var selectedTodaySetID: UUID?
    @State var reuseMessage: String?
    @State var pendingTodayDelete: [UUID] = []
    @State var showTodayDeleteConfirmation = false
    @AppStorage("plateSortAscending") var plateSortAscending = false
    @AppStorage("trainingStartupStyle") var trainingStartupStyle = "automatic"
    @AppStorage("trainingStartupSound") var trainingStartupSound = true

    var isOuterCalendar: Bool {
        !isTrainingMode && horizontalSizeClass == .compact && verticalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            GeometryReader { safeGeometry in
            GeometryReader { geometry in
                ZStack {
                    if isTrainingMode {
                        Color.black.ignoresSafeArea()
                    } else {
                        TrainingBackground()
                    }
                Group {
                    if isTrainingMode {
                        let fold = horizontalFold(in: geometry) ?? CGRect(x: 0, y: geometry.size.height * 0.45, width: geometry.size.width, height: 0)
                        let leadingInset = safeGeometry.safeAreaInsets.leading
                        let trailingInset = safeGeometry.safeAreaInsets.trailing
                        FoldedTrainingView(fold: fold, height: geometry.size.height, width: geometry.size.width, isLandscape: geometry.size.width > geometry.size.height, leadingInset: leadingInset, trailingInset: trailingInset, bottomInset: safeGeometry.safeAreaInsets.bottom, reps: $reps, note: $note, deadline: $restDeadline, pausedSeconds: $pausedRestSeconds, duration: $restDuration, totalDuration: $restTotalDuration, showFullLayout: $showFullLayout, menuFocus: $arcadeMenuFocus, selectedPlateID: $selectedFoldedPlateID, showWeightCalculator: $showFoldedWeightCalculator, pendingWeightSelection: $pendingFoldedWeightSelection, showCustomActionEditor: $showFoldedCustomActionEditor, customActionDraft: $foldedCustomActionDraft, fullLayout: AnyView(foldedFullLayout), menuBack: closeTrainingMenu, menuConfirm: confirmFocusedTrainingMenu, record: recordSet, reuse: reusePreviousSet, exit: exitTrainingMode, fullStartup: fullTrainingStartup, isExiting: isTrainingModeExiting)
                            .transition(.opacity)
                    } else {
                        dashboard.transition(.opacity)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.12), value: isTrainingMode)
                }
                .onAppear {
                    isTrainingLandscape = geometry.size.width > geometry.size.height
                    isHorizontalFolded = horizontalFold(in: geometry) != nil
                    if isHorizontalFolded { beginTrainingMode(manual: false) }
                }
                .onChange(of: geometry.size) { size in
                    isTrainingLandscape = size.width > size.height
                }
                .onChange(of: horizontalFold(in: geometry) != nil) { folded in
                    isHorizontalFolded = folded
                    if folded {
                        if isTrainingModeExiting { trainingExitTask?.cancel(); isTrainingModeExiting = false }
                        if !isTrainingMode { beginTrainingMode(manual: false) }
                    } else if !trainingModeManuallyOpened && isTrainingMode {
                        closeTrainingMode()
                    }
                    showFullLayout = false
                }
            }
            .ignoresSafeArea(.container, edges: isOuterCalendar || isTrainingMode ? .all : [])
            .ignoresSafeArea(.keyboard, edges: isTrainingMode ? .bottom : [])
            }
            .toolbar(isTrainingMode || isOuterCalendar ? .hidden : .visible, for: .navigationBar)
            .statusBarHidden(isTrainingMode || isOuterCalendar)
            .navigationTitle("蛛莉铁馆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isTrainingMode && !isOuterCalendar {
                    ToolbarItem(placement: .principal) { CyberGymTitle() }
                }
            }
            .alert("无法复用上一组", isPresented: Binding(get: { reuseMessage != nil }, set: { if !$0 { reuseMessage = nil } })) {
                Button("好", role: .cancel) { reuseMessage = nil }
            } message: { Text(reuseMessage ?? "") }
            .alert("结束本次训练？", isPresented: $showFinishAfterVictory) {
                Button("结束训练") {
                    TrainingSound.confirm()
                    store.finishTraining()
                    celebratingPlanID = nil
                }
                Button("继续训练", role: .cancel) { celebratingPlanID = nil }
            } message: { Text("已记录的训练数据会保留。") }
            .alert("请先开始训练", isPresented: $showStartRequired) {
                Button("好", role: .cancel) {}
            } message: { Text("开始训练并设置目标后，才能记录组数。") }
            .sheet(isPresented: $showRecordForm) {
                TrainingEntryForm(title: "记录这一组", action: $recordAction, reps: $recordReps) {
                    guard store.activePlan != nil else { showRecordForm = false; showStartRequired = true; return }
                    note = recordAction.trimmingCharacters(in: .whitespacesAndNewlines)
                    reps = recordReps
                    store.rememberCustomAction(note)
                    store.record(reps: reps, note: note)
                    if let actions = store.activePlan?.actions,
                       let currentIndex = actions.firstIndex(where: { TrainingStore.actionKey($0.name) == TrainingStore.actionKey(note) }),
                       store.completedCount(for: actions[currentIndex]) >= actions[currentIndex].target {
                        let remaining = Array(actions.dropFirst(currentIndex + 1)) + Array(actions.prefix(currentIndex))
                        if let next = remaining.first(where: { store.completedCount(for: $0) < $0.target }) {
                            note = next.name
                            if let plannedReps = next.reps { reps = plannedReps }
                        }
                    }
                    pausedRestSeconds = nil
                    restTotalDuration = restDuration
                    restDeadline = Date().addingTimeInterval(Double(restDuration))
                    showRecordForm = false
                }
                .presentationDetents(isHorizontalFolded ? [.fraction(0.5)] : [.large])
            }
            .fullScreenCover(isPresented: Binding(get: { !isTrainingMode && showTools }, set: { showTools = $0 })) { toolsPage }
            .fullScreenCover(isPresented: Binding(get: { !isTrainingMode && showOverview }, set: { showOverview = $0 })) { overviewPage }
            .sheet(isPresented: Binding(get: { !isTrainingMode && showCalculator }, set: { showCalculator = $0 })) { calculatorPage }
        }
        .tint(TrainingTheme.accent)
        .environment(\.trainingModeUI, isTrainingMode)
        .sheet(item: $shortcutShareImage) { item in
            TrainingSharePreview(image: item.image)
                .onAppear { ShareShortcutLog.write("preview_appeared") }
        }
        .alert("无法生成今日卡片", isPresented: Binding(get: { shortcutShareError != nil }, set: { if !$0 { shortcutShareError = nil } })) {
            Button("好", role: .cancel) { shortcutShareError = nil }
        } message: { Text(shortcutShareError ?? "") }
        .onOpenURL { url in
            shortcuts.receiveURL(url, source: "swiftui_on_open_url")
            handleShareShortcut()
        }
        .onChange(of: shortcuts.pendingShare) { _ in handleShareShortcut() }
        .task {
            handleShareShortcut()
            TrainingWidgetBridge.shared.publish(store: store)
            if let restored = TrainingWidgetBridge.shared.restoredRest() {
                restDeadline = restored.deadline
                pausedRestSeconds = restored.pausedSeconds
                note = restored.action
                reps = restored.reps
            } else {
                syncRestActivity()
            }
            await advice.refresh(sets: store.sets)
        }
        .onChange(of: store.celebrationID) { celebration in
            if celebration != nil {
                celebratingPlanID = store.activePlan?.id
            } else if let planID = celebratingPlanID {
                if store.activePlan?.id == planID {
                    showFinishAfterVictory = true
                } else {
                    celebratingPlanID = nil
                }
            }
        }
        .onChange(of: restDeadline) { _ in syncRestActivity() }
        .onChange(of: pausedRestSeconds) { _ in syncRestActivity() }
        .onChange(of: note) { _ in syncRestActivity() }
        .onChange(of: reps) { _ in syncRestActivity() }
        .onChange(of: store.total) { _ in syncRestActivity() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                handleShareShortcut()
                Task { await advice.refresh(sets: store.sets) }
            }
        }
    }

    func handleShareShortcut() {
        ShareShortcutLog.write("handle_request", ["pending": shortcuts.pendingShare, "active": scenePhase == .active])
        guard shortcuts.pendingShare, scenePhase == .active else { return }
        shortcuts.pendingShare = false
        showTools = false
        showOverview = false
        showCalculator = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            let todayCount = store.sets.filter { Calendar.current.isDateInToday($0.date) }.count
            ShareShortcutLog.write("render_start", ["todayCount": todayCount])
            guard todayCount > 0 else {
                ShareShortcutLog.write("no_training_today")
                shortcutShareError = "今天还没有训练记录，记录训练后即可生成卡片。"
                return
            }
            if let image = TrainingShareRenderer.makeImage(store: store, date: Date(), energyBodyWeight: energyBodyWeight) {
                ShareShortcutLog.write("render_succeeded", ["width": Int(image.size.width), "height": Int(image.size.height)])
                shortcutShareImage = SharedTrainingImage(image: image)
            } else {
                ShareShortcutLog.write("render_failed")
                shortcutShareError = "卡片生成失败，请稍后重试。"
            }
        }
    }

    func enterTrainingMode() {
        TrainingFeedback.tap()
        beginTrainingMode(manual: true)
    }

    func beginTrainingMode(manual: Bool) {
        trainingExitTask?.cancel()
        isTrainingModeExiting = false
        trainingModeManuallyOpened = manual
        fullTrainingStartup = trainingStartupStyle == "full" || (trainingStartupStyle == "automatic" && !hasStartedTrainingMode)
        hasStartedTrainingMode = true
        isTrainingMode = true
    }

    func exitTrainingMode() {
        TrainingFeedback.tap()
        trainingModeManuallyOpened = false
        closeTrainingMode()
    }

    func closeTrainingMode() {
        guard !isTrainingModeExiting else { return }
        isTrainingModeExiting = true
        trainingExitTask?.cancel()
        trainingExitTask = Task { @MainActor in
            if !reduceMotion {
                do { try await Task.sleep(nanoseconds: 3_200_000_000) } catch { return }
            }
            guard !Task.isCancelled else { return }
            isTrainingMode = false
            isTrainingModeExiting = false
            showFullLayout = false
        }
    }

    func horizontalFold(in geometry: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            return geometry.reservedRegions(kind: .division).map(\.frame).first {
                $0.width > $0.height && $0.minY > 0 && $0.maxY < geometry.size.height
            }
        }
        return nil
    }

    func syncRestActivity() {
        TrainingWidgetBridge.shared.syncRest(deadline: restDeadline, paused: pausedRestSeconds,
                                             action: note, weight: store.total, reps: reps)
    }

    func recordSet() {
        guard store.activePlan != nil else { showStartRequired = true; return }
        recordAction = note
        recordReps = reps
        showRecordForm = true
    }


}
