import SwiftUI
import UIKit

extension ContentView {
    var dashboard: some View {
        dashboard(compactMenuEnabled: true)
    }

    func dashboard(compactMenuEnabled: Bool) -> some View {
        TrainingDashboard(compactMenuEnabled: compactMenuEnabled, calendarDate: $calendarDate, trainingModeAnchor: $trainingModeAnchor, overviewContent: AnyView(overviewContent), statisticsContent: AnyView(innerStatisticsContent), adviceContent: AnyView(innerAdviceContent), selectedInnerTab: $selectedInnerTab, toolsContent: AnyView(toolsContent()), innerToolsContent: AnyView(toolsContent(includeMaintenance: false)), maintenanceContent: AnyView(maintenanceContent), reps: $reps, note: $note, deadline: $restDeadline, duration: $restDuration,
                          pausedSeconds: $pausedRestSeconds, record: recordSet, reuse: reusePreviousSet,
                          showCalculator: { showCalculator = true }, showOverview: { showOverview = true },
                          showTools: { showTools = true }, enterTrainingMode: enterTrainingMode)
    }

    func confirmFocusedTrainingMenu() -> Bool {
        guard !showTools && !showOverview && !showCalculator && !showBarSettings && !showAdd && editingPlate == nil else { return false }
        switch arcadeMenuFocus {
        case 0: showCalculator = true
        case 1, 2: showTools = true
        default: return false
        }
        return true
    }

    func closeTrainingMenu() {
        if showBarSettings { showBarSettings = false }
        else if showAdd { showAdd = false }
        else if editingPlate != nil { editingPlate = nil }
        else if showCalculator { showCalculator = false }
        else if showTools { showTools = false }
        else if showOverview { showOverview = false }
        else { showFullLayout = false }
    }

    var foldedFullLayout: some View {
        VStack(spacing: 0) {
            HStack {
                if !isTrainingLandscape {
                    Button("返回", action: closeTrainingMenu)
                        .buttonStyle(TrainingModalButtonStyle())
                }
                Spacer()
                Text(showCalculator ? "自动配重" : showTools ? "工具与设置" : showOverview ? "训练概览" : "完整功能")
                    .font(.system(size: 15, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(Color(red: 0.72, green: 0.94, blue: 0.77)).lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .background(Color(red: 0.08, green: 0.03, blue: 0.14))
            Group {
                if showBarSettings {
                    BarWeightView(onClose: { showBarSettings = false })
                } else if showAdd {
                    AddPlateView(onClose: { showAdd = false })
                } else if let plate = editingPlate {
                    AddPlateView(plate: plate, onClose: { editingPlate = nil }).id(plate.id)
                } else if showTools {
                    toolsContent()
                } else if showOverview {
                    overviewContent
                } else if showCalculator {
                    List { WeightCalculatorSection().listRowBackground(TrainingTheme.card) }
                        .scrollContentBackground(.hidden).background(TrainingBackground())
                } else {
                    dashboard(compactMenuEnabled: false).background(TrainingBackground())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .environment(\.colorScheme, .dark)
        .environment(\.handheldControls, false)
        .environment(\.arcadeMenuFocus, arcadeMenuFocus)
    }

    var toolsPage: some View {
        NavigationStack {
            toolsContent()
                .navigationTitle("工具与设置")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button { showTools = false } label: { Label("返回", systemImage: "chevron.backward") }.buttonStyle(TrainingModalButtonStyle()) } }
        }
    }

    func toolsContent(includeMaintenance: Bool = true) -> some View {
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
        .sheet(isPresented: Binding(get: { !isTrainingMode && showBarSettings }, set: { showBarSettings = $0 })) { BarWeightView() }
        .sheet(isPresented: Binding(get: { !isTrainingMode && showAdd }, set: { showAdd = $0 })) { AddPlateView() }
        .sheet(item: Binding(get: { isTrainingMode ? nil : editingPlate }, set: { editingPlate = $0 })) { plate in AddPlateView(plate: plate) }
    }

    var trainingAnimationSettings: some View {
        Section("训练模式动画") {
            Picker("启动动画", selection: $trainingStartupStyle) {
                Text("首次完整，之后快速").tag("automatic")
                Text("完整启动").tag("full")
                Text("快速启动").tag("quick")
            }
            Toggle("启动音效", isOn: $trainingStartupSound)
        }
    }

    var maintenanceContent: some View {
        List {
            BackupSection().listRowBackground(TrainingTheme.card)
            ProvisioningStatusSection().listRowBackground(TrainingTheme.card)
        }.scrollContentBackground(.hidden).background(TrainingBackground())
    }

    func toolsVerticalFold(in geometry: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            return geometry.reservedRegions(kind: .division).map(\.frame).first {
                $0.height > $0.width && $0.minX > 12 && $0.maxX < geometry.size.width - 12
            }
        }
        return nil
    }

    var overviewPage: some View {
        NavigationStack {
            overviewContent
                .navigationTitle("训练概览")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button { showOverview = false } label: { Label("返回", systemImage: "chevron.backward") }.buttonStyle(TrainingModalButtonStyle()) } }
        }
    }

    var overviewContent: some View {
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

    var innerStatisticsContent: some View {
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

    var innerAdviceContent: some View {
        TrainingAdviceSheet(manager: advice)
    }

    var calculatorPage: some View {
        NavigationStack {
            List { WeightCalculatorSection().listRowBackground(TrainingTheme.card) }
                .scrollContentBackground(.hidden).background(TrainingBackground())
                .navigationTitle("自动配重")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showCalculator = false }.buttonStyle(TrainingModalButtonStyle()) } }
        }
    }

}
