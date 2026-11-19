import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var advice = TrainingAdvice()
    @StateObject private var shortcuts = TrainingShortcuts.shared
    @State private var shortcutShareImage: SharedTrainingImage?
    @State private var shortcutShareError: String?
    @AppStorage("energyBodyWeight") private var energyBodyWeight = ""
    @State private var reps = 10
    @State private var showRecordForm = false
    @State private var showStartRequired = false
    @State private var showFinishAfterVictory = false
    @State private var celebratingPlanID: UUID?
    @State private var recordAction = ""
    @State private var recordReps = 10
    @State private var restDeadline: Date?
    @State private var restDuration = 90
    @State private var restTotalDuration = 90
    @State private var pausedRestSeconds: Int?
    @State private var showFullLayout = false
    @State private var calendarDate = Date()
    @State private var trainingModeAnchor: CGRect?
    @State private var selectedFoldedPlateID: UUID?
    @State private var showFoldedWeightCalculator = false
    @State private var pendingFoldedWeightSelection: [UUID: Int]?
    @State private var showFoldedCustomActionEditor = false
    @State private var foldedCustomActionDraft = ""
    @State private var isHorizontalFolded = false
    @State private var isTrainingMode = false
    @State private var trainingModeManuallyOpened = false
    @State private var hasStartedTrainingMode = false
    @State private var fullTrainingStartup = false
    @State private var isTrainingModeExiting = false
    @State private var trainingExitTask: Task<Void, Never>?
    @State private var showAdd = false
    @State private var showHistory = false
    @State private var showOverview = false
    @State private var selectedInnerTab = 0
    @State private var showTools = false
    @State private var showCalculator = false
    @State private var editingPlate: Plate?
    @State private var note = ""
    @State private var showBarSettings = false
    @State private var editingTodaySet: TrainingSet?
    @State private var selectedTodaySetID: UUID?
    @State private var reuseMessage: String?
    @State private var pendingTodayDelete: [UUID] = []
    @State private var showTodayDeleteConfirmation = false
    @AppStorage("plateSortAscending") private var plateSortAscending = false
    @AppStorage("trainingStartupStyle") private var trainingStartupStyle = "automatic"
    @AppStorage("trainingStartupSound") private var trainingStartupSound = true

    private var isOuterCalendar: Bool {
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
                        FoldedTrainingView(fold: fold, height: geometry.size.height, width: geometry.size.width, isLandscape: geometry.size.width > geometry.size.height, leadingInset: leadingInset, trailingInset: trailingInset, bottomInset: safeGeometry.safeAreaInsets.bottom, reps: $reps, note: $note, deadline: $restDeadline, pausedSeconds: $pausedRestSeconds, duration: $restDuration, totalDuration: $restTotalDuration, showFullLayout: $showFullLayout, selectedPlateID: $selectedFoldedPlateID, showWeightCalculator: $showFoldedWeightCalculator, pendingWeightSelection: $pendingFoldedWeightSelection, showCustomActionEditor: $showFoldedCustomActionEditor, customActionDraft: $foldedCustomActionDraft, fullLayout: AnyView(foldedFullLayout), record: recordSet, reuse: reusePreviousSet, exit: exitTrainingMode, fullStartup: fullTrainingStartup, isExiting: isTrainingModeExiting)
                            .transition(.opacity)
                    } else {
                        dashboard.transition(.opacity)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.12), value: isTrainingMode)
                }
                .onAppear {
                    isHorizontalFolded = horizontalFold(in: geometry) != nil
                    if isHorizontalFolded { beginTrainingMode(manual: false) }
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
            .fullScreenCover(isPresented: $showTools) { toolsPage }
            .fullScreenCover(isPresented: $showOverview) { overviewPage }
            .sheet(isPresented: $showCalculator) { calculatorPage }
        }
        .tint(TrainingTheme.accent)
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

    private func handleShareShortcut() {
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

    private var dashboard: some View {
        dashboard(compactMenuEnabled: true)
    }

    private func dashboard(compactMenuEnabled: Bool) -> some View {
        TrainingDashboard(compactMenuEnabled: compactMenuEnabled, calendarDate: $calendarDate, trainingModeAnchor: $trainingModeAnchor, overviewContent: AnyView(overviewContent), statisticsContent: AnyView(innerStatisticsContent), adviceContent: AnyView(innerAdviceContent), selectedInnerTab: $selectedInnerTab, toolsContent: AnyView(toolsContent()), innerToolsContent: AnyView(toolsContent(includeMaintenance: false)), maintenanceContent: AnyView(maintenanceContent), reps: $reps, note: $note, deadline: $restDeadline, duration: $restDuration,
                          pausedSeconds: $pausedRestSeconds, record: recordSet, reuse: reusePreviousSet,
                          showCalculator: { showCalculator = true }, showOverview: { showOverview = true },
                          showTools: { showTools = true }, enterTrainingMode: enterTrainingMode)
    }

    private var foldedFullLayout: some View {
        NavigationStack {
            dashboard(compactMenuEnabled: false).background(TrainingBackground())
                .navigationTitle("完整功能")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showFullLayout = false } } }
                .fullScreenCover(isPresented: $showTools) { toolsPage }
                .fullScreenCover(isPresented: $showOverview) { overviewPage }
                .sheet(isPresented: $showCalculator) { calculatorPage }
        }
    }

    private var toolsPage: some View {
        NavigationStack {
            toolsContent()
                .navigationTitle("工具与设置")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button { showTools = false } label: { Label("返回", systemImage: "chevron.backward") } } }
        }
    }

    private func toolsContent(includeMaintenance: Bool = true) -> some View {
        GeometryReader { geometry in
            if horizontalSizeClass == .regular && geometry.size.width >= geometry.size.height {
                let fold = toolsVerticalFold(in: geometry)
                let gap: CGFloat = fold?.width ?? 12
                let left = fold.map { max(0, $0.minX - 12) } ?? max(0, (geometry.size.width - 36) / 2)
                let right = fold.map { max(0, geometry.size.width - $0.maxX - 12) } ?? left
                HStack(alignment: .top, spacing: 0) {
                    List { plateSection(includeAdd: false).listRowBackground(TrainingTheme.card) }
                        .scrollContentBackground(.hidden).frame(width: left)
                    Color.clear.frame(width: gap)
                    List {
                        WeightCalculatorSection().listRowBackground(TrainingTheme.card)
                        barSection.listRowBackground(TrainingTheme.card)
                        trainingAnimationSettings.listRowBackground(TrainingTheme.card)
                        Section {
                            Button { showAdd = true } label: {
                                TrainingRowLabel(title: "添加杠铃片规格", systemImage: "plus.circle")
                            }.buttonStyle(.plain)
                        }.listRowBackground(TrainingTheme.card)
                        if includeMaintenance {
                            BackupSection().listRowBackground(TrainingTheme.card)
                            ProvisioningStatusSection().listRowBackground(TrainingTheme.card)
                        }
                    }
                    .scrollContentBackground(.hidden).frame(width: right)
                }.padding(.horizontal, 12)
            } else {
                List {
                    WeightCalculatorSection().listRowBackground(TrainingTheme.card)
                    plateSection().listRowBackground(TrainingTheme.card)
                    barSection.listRowBackground(TrainingTheme.card)
                    trainingAnimationSettings.listRowBackground(TrainingTheme.card)
                    if includeMaintenance {
                        BackupSection().listRowBackground(TrainingTheme.card)
                        ProvisioningStatusSection().listRowBackground(TrainingTheme.card)
                    }
                }.scrollContentBackground(.hidden)
            }
        }
        .background(TrainingBackground())
        .sheet(isPresented: $showBarSettings) { BarWeightView() }
        .sheet(isPresented: $showAdd) { AddPlateView() }
        .sheet(item: $editingPlate) { plate in AddPlateView(plate: plate) }
    }

    private var trainingAnimationSettings: some View {
        Section("训练模式动画") {
            Picker("启动动画", selection: $trainingStartupStyle) {
                Text("首次完整，之后快速").tag("automatic")
                Text("完整启动").tag("full")
                Text("快速启动").tag("quick")
            }
            Toggle("启动音效", isOn: $trainingStartupSound)
        }
    }

    private var maintenanceContent: some View {
        List {
            BackupSection().listRowBackground(TrainingTheme.card)
            ProvisioningStatusSection().listRowBackground(TrainingTheme.card)
        }.scrollContentBackground(.hidden).background(TrainingBackground())
    }

    private func toolsVerticalFold(in geometry: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            return geometry.reservedRegions(kind: .division).map(\.frame).first {
                $0.height > $0.width && $0.minX > 12 && $0.maxX < geometry.size.width - 12
            }
        }
        return nil
    }

    private var overviewPage: some View {
        NavigationStack {
            overviewContent
                .navigationTitle("训练概览")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button { showOverview = false } label: { Label("返回", systemImage: "chevron.backward") } } }
        }
    }

    private var overviewContent: some View {
        List {
            statisticsSection().listRowBackground(TrainingTheme.card)
            TrainingAdviceSection(manager: advice).listRowBackground(TrainingTheme.card)
        }
        .scrollContentBackground(.hidden).background(TrainingBackground())
        .toolbar { ToolbarItem(placement: .primaryAction) { TrainingShareButton(date: Date(), compact: true) } }
        .alert("删除训练记录？", isPresented: $showTodayDeleteConfirmation) {
            Button("删除", role: .destructive) { store.sets.removeAll { pendingTodayDelete.contains($0.id) } }
            Button("取消", role: .cancel) { pendingTodayDelete = [] }
        } message: { Text("删除后无法撤销。") }
        .fullScreenCover(isPresented: $showHistory) { HistoryView() }
        .sheet(item: $editingTodaySet) { set in EditNoteView(set: set) }
    }

    private var innerStatisticsContent: some View {
        List {
            statisticsSection(inner: true).listRowBackground(Color.clear)
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
        .alert("删除训练记录？", isPresented: $showTodayDeleteConfirmation) {
            Button("删除", role: .destructive) { store.sets.removeAll { pendingTodayDelete.contains($0.id) } }
            Button("取消", role: .cancel) { pendingTodayDelete = [] }
        } message: { Text("删除后无法撤销。") }
        .sheet(item: $editingTodaySet) { set in EditNoteView(set: set) }
    }

    private var innerAdviceContent: some View {
        TrainingAdviceSheet(manager: advice)
    }

    private var calculatorPage: some View {
        NavigationStack {
            List { WeightCalculatorSection().listRowBackground(TrainingTheme.card) }
                .scrollContentBackground(.hidden).background(TrainingBackground())
                .navigationTitle("自动配重")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showCalculator = false } } }
        }
    }

    private func enterTrainingMode() {
        TrainingFeedback.tap()
        beginTrainingMode(manual: true)
    }

    private func beginTrainingMode(manual: Bool) {
        trainingExitTask?.cancel()
        isTrainingModeExiting = false
        trainingModeManuallyOpened = manual
        fullTrainingStartup = trainingStartupStyle == "full" || (trainingStartupStyle == "automatic" && !hasStartedTrainingMode)
        hasStartedTrainingMode = true
        isTrainingMode = true
    }

    private func exitTrainingMode() {
        TrainingFeedback.tap()
        trainingModeManuallyOpened = false
        closeTrainingMode()
    }

    private func closeTrainingMode() {
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

    private func horizontalFold(in geometry: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            return geometry.reservedRegions(kind: .division).map(\.frame).first {
                $0.width > $0.height && $0.minY > 0 && $0.maxY < geometry.size.height
            }
        }
        return nil
    }

    private func syncRestActivity() {
        TrainingWidgetBridge.shared.syncRest(deadline: restDeadline, paused: pausedRestSeconds,
                                             action: note, weight: store.total, reps: reps)
    }

    private func recordSet() {
        guard store.activePlan != nil else { showStartRequired = true; return }
        recordAction = note
        recordReps = reps
        showRecordForm = true
    }

    private var weightSection: some View {
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

    private var singleSideDescription: String {
        let parts = store.plates.sorted { $0.kilograms > $1.kilograms }.compactMap { plate -> String? in
            let count = store.selected[plate.id, default: 0]
            return count > 0 ? "\(plate.label) × \(count)" : nil
        }
        return parts.isEmpty ? "单边：未装片" : "单边：" + parts.joined(separator: " + ")
    }

    private func plateSection(includeAdd: Bool = true) -> some View {
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

    private var sortedPlates: [Plate] {
        store.plates.enumerated().sorted { left, right in
            if left.element.kilograms == right.element.kilograms { return left.offset < right.offset }
            return plateSortAscending ? left.element.kilograms < right.element.kilograms : left.element.kilograms > right.element.kilograms
        }.map { $0.element }
    }

    private var barSection: some View {
        Section("杠铃杆") {
            Button { showBarSettings = true } label: {
                TrainingRowLabel(title: "设置杆重：\(store.barWeight.formattedWeight) kg", systemImage: "scalemass")
            }.buttonStyle(.plain)
        }
    }

    private var recordSection: some View {
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

    private func reusePreviousSet() {
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

    private var todayEnergySummary: String {
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

    private func statisticsSection(inner: Bool = false) -> some View {
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

    private func overviewStat(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color)
                .lineLimit(2).minimumScaleFactor(0.7).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var todaySets: [TrainingSet] {
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

struct AddPlateView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.dismiss) private var dismiss
    let plate: Plate?
    @State private var weight: String
    @State private var unit: String
    @State private var color: Color
    @State private var error = false
    @State private var availablePairs: Int

    init(plate: Plate? = nil) {
        self.plate = plate
        _weight = State(initialValue: plate?.weight.formattedWeight ?? "")
        _unit = State(initialValue: plate?.unit ?? "kg")
        _color = State(initialValue: Color(hex: plate?.colorHex))
        _availablePairs = State(initialValue: plate?.availablePairs ?? 1)
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
                ToolbarItem(placement: .navigationBarLeading) { Button { dismiss() } label: { Label("返回", systemImage: "chevron.left") }.tint(.primary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let normalized = weight.replacingOccurrences(of: ",", with: ".")
                        if let value = Double(normalized), store.savePlate(id: plate?.id, weight: value, unit: unit, colorHex: color.hexValue, availablePairs: availablePairs) { dismiss() }
                        else { error = true }
                    }
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

