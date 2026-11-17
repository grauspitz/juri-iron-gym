import SwiftUI

struct TrainingDashboard: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var calendarDate = Date()
    @State private var calendarVisible = false
    @State private var showAdvice = false
    var compactMenuEnabled = true
    let overviewContent: AnyView
    let statisticsContent: AnyView
    let adviceContent: AnyView
    @Binding var selectedInnerTab: Int
    let toolsContent: AnyView
    let innerToolsContent: AnyView
    let maintenanceContent: AnyView

    // 布局适配优先级：iPhone Duo 内屏体验第一，按可用空间和系统折痕组织操作。
    private var usesCompactMenu: Bool {
        compactMenuEnabled && horizontalSizeClass == .compact && verticalSizeClass == .regular
    }
    @Binding var reps: Int
    @Binding var note: String
    @Binding var deadline: Date?
    @Binding var duration: Int
    @Binding var pausedSeconds: Int?
    let record: () -> Void
    let reuse: () -> Void
    let showCalculator: () -> Void
    let showOverview: () -> Void
    let showTools: () -> Void

    init(compactMenuEnabled: Bool = true, overviewContent: AnyView, statisticsContent: AnyView, adviceContent: AnyView, selectedInnerTab: Binding<Int>, toolsContent: AnyView, innerToolsContent: AnyView, maintenanceContent: AnyView, reps: Binding<Int>, note: Binding<String>, deadline: Binding<Date?>,
         duration: Binding<Int>, pausedSeconds: Binding<Int?>, record: @escaping () -> Void,
         reuse: @escaping () -> Void, showCalculator: @escaping () -> Void,
         showOverview: @escaping () -> Void, showTools: @escaping () -> Void) {
        self.compactMenuEnabled = compactMenuEnabled
        self.overviewContent = overviewContent
        self.statisticsContent = statisticsContent
        self.adviceContent = adviceContent
        self._selectedInnerTab = selectedInnerTab
        self.toolsContent = toolsContent
        self.innerToolsContent = innerToolsContent
        self.maintenanceContent = maintenanceContent
        self._reps = reps
        self._note = note
        self._deadline = deadline
        self._duration = duration
        self._pausedSeconds = pausedSeconds
        self.record = record
        self.reuse = reuse
        self.showCalculator = showCalculator
        self.showOverview = showOverview
        self.showTools = showTools
    }

    var body: some View {
        GeometryReader { geometry in
            if usesCompactMenu {
                compactTabs
            } else if compactMenuEnabled && horizontalSizeClass == .compact && verticalSizeClass == .compact {
                outerLandscape
            } else if compactMenuEnabled && horizontalSizeClass == .regular {
                innerTabs
            } else {
                dashboardContent()
            }
        }
    }

    private var outerLandscape: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 1280, geometry.size.height / 720)
            let daySets = store.sets.filter { Calendar.current.isDate($0.date, inSameDayAs: calendarDate) }
            let volume = daySets.reduce(0) { $0 + $1.weight * Double($1.reps) }
            if scale < 0.61 || dynamicTypeSize.isAccessibilitySize {
                ScrollView { calendarCard.padding(12) }
                    .background(TrainingBackground())
            } else {
                ZStack(alignment: .topLeading) {
                    TrainingLoopVideo(name: "calendar", fileExtension: "mov", isVisible: calendarVisible)
                        .frame(width: 1280, height: 720)
                    OuterLandscapeCalendar(selectedDate: $calendarDate, sets: store.sets)
                        .frame(width: 1280, height: 720)
                    HStack(spacing: 20) {
                        Text("\(calendarDate.formatted(date: .abbreviated, time: .omitted)) · \(daySets.count) 组 · \(volume.formattedWeight) kg")
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Spacer(minLength: 0)
                        NavigationLink { DayHistoryView(date: calendarDate).toolbar(.visible, for: .navigationBar) } label: {
                            Label("查看记录", systemImage: "list.bullet")
                        }
                        TrainingShareButton(date: calendarDate, compact: true)
                    }
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 3)
                    .frame(width: 530, height: 42)
                    .position(x: 544, y: 544)
                }
                .frame(width: 1280, height: 720, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: 1280 * scale, height: 720 * scale, alignment: .topLeading)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                .clipped()
            }
        }
        .background(Color.black)
        .onAppear { calendarVisible = true }
        .onDisappear { calendarVisible = false }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var compactTabs: some View {
        TabView {
            dashboardContent().background(TrainingBackground()).tabItem { Label("首页", systemImage: "house") }
            compactPage { expandedPlanCard; recordCard; restCard }.background(TrainingBackground()).tabItem { Label("训练", systemImage: "figure.strengthtraining.traditional") }
            compactPage { calendarCard }.background(TrainingBackground()).tabItem { Label("日历", systemImage: "calendar") }
            overviewContent.tabItem { Label("概览", systemImage: "chart.bar.fill") }
            toolsContent.tabItem { Label("工具", systemImage: "slider.horizontal.3") }
        }
        .tint(TrainingTheme.teal)
    }

    // iPhone Duo 内屏优先：保留系统 Dock，使用 size class 与可用空间适配。
    private var innerTabs: some View {
        TabView(selection: $selectedInnerTab) {
            innerDashboard.background(TrainingBackground())
                .tabItem { Label("训练", systemImage: "figure.strengthtraining.traditional") }.tag(0)
            InnerCalendarPage(selectedDate: $calendarDate).background(TrainingBackground())
                .tabItem { Label("日历", systemImage: "calendar") }.tag(1)
            innerToolsContent.tabItem { Label("工具", systemImage: "slider.horizontal.3") }.tag(2)
            maintenanceContent.tabItem { Label("备份与配置", systemImage: "externaldrive.badge.checkmark") }.tag(3)
        }
        .tint(TrainingTheme.teal)
        .sheet(isPresented: $showAdvice) {
            adviceContent
        }
    }

    private var innerDashboard: some View {
        GeometryReader { geometry in
            let fold = verticalFold(in: geometry)
            let gap: CGFloat = fold?.width ?? 12
            let leftWidth = fold.map { max(0, $0.minX - 12) } ?? max(0, (geometry.size.width - 36) / 2)
            let rightWidth = fold.map { max(0, geometry.size.width - $0.maxX - 12) } ?? leftWidth
            if geometry.size.width >= geometry.size.height {
                let availableHeight = max(0, geometry.size.height - 36)
                let topHeight = availableHeight * (store.activePlan == nil ? 0.42 : 0.52)
                let bottomHeight = availableHeight - topHeight
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 0) {
                        innerCard(width: leftWidth, height: topHeight) {
                            HStack {
                                Text("当前重量").font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(store.total.formattedWeight) kg").font(.title2.bold())
                                    .monospacedDigit().foregroundStyle(TrainingTheme.teal)
                            }
                        } content: { ScrollView { innerTrainingPanel } }
                        Color.clear.frame(width: gap)
                        innerCard(width: rightWidth, height: topHeight) {
                            Label("训练计划", systemImage: "checklist").font(.headline)
                        } content: { ScrollView { innerSessionPanel } }
                    }
                    HStack(alignment: .top, spacing: 0) {
                        innerCard(width: leftWidth, height: bottomHeight) {
                            HStack {
                                Label("杠铃片", systemImage: "circle.grid.2x2").font(.headline)
                                Spacer()
                                Button("管理", action: showTools).font(.subheadline)
                            }
                        } content: { innerPlatesPanel }
                        Color.clear.frame(width: gap)
                        innerCard(width: rightWidth, height: bottomHeight) {
                            HStack {
                                Text("今日统计").font(.headline)
                                Spacer()
                                adviceButton
                            }
                        } content: { statisticsContent }
                    }
                }.padding(12)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        innerNaturalCard(width: max(0, geometry.size.width - 24)) {
                            HStack {
                                Text("当前重量").font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(store.total.formattedWeight) kg").font(.title2.bold()).foregroundStyle(TrainingTheme.teal)
                            }
                        } content: { innerTrainingPanel }
                        innerNaturalCard(width: max(0, geometry.size.width - 24)) { Label("训练计划", systemImage: "checklist").font(.headline) }
                            content: { innerSessionPanel }
                        innerCard(width: max(0, geometry.size.width - 24), height: 300) {
                            HStack { Label("杠铃片", systemImage: "circle.grid.2x2").font(.headline); Spacer(); Button("管理", action: showTools) }
                        } content: { innerPlatesPanel }
                        innerCard(width: max(0, geometry.size.width - 24), height: 300) {
                            HStack { Text("今日统计").font(.headline); Spacer(); adviceButton }
                        } content: { statisticsContent }
                    }.padding(12)
                }
            }

        }
    }

    private func innerNaturalCard<Header: View, Content: View>(width: CGFloat,
        @ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header()
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12).frame(width: width, alignment: .leading)
        .background(TrainingTheme.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private func innerCard<Header: View, Content: View>(width: CGFloat, height: CGFloat,
        @ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header()
            content().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(12).frame(width: width, height: height, alignment: .topLeading)
        .background(TrainingTheme.card, in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var adviceButton: some View {
        Button { showAdvice = true } label: {
            Label("AI 训练建议", systemImage: "sparkles")
                .font(.caption.weight(.semibold)).lineLimit(1)
        }.buttonStyle(.bordered)
    }

    private var innerTrainingPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            BarbellView(plates: store.plates, selected: store.selected).frame(height: 64)
            HStack {
                WeightStepControls()
                Spacer(minLength: 0)
                Button("自动配重", action: showCalculator).font(.subheadline)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var innerPlatesPanel: some View {
        let plates = store.plates.sorted { $0.kilograms > $1.kilograms }
        return ScrollView {
            if plates.isEmpty {
                Button("添加杠铃片", action: showTools).frame(maxWidth: .infinity, minHeight: 44)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(plates) { plate in
                        HStack(spacing: 4) {
                            RealisticPlateView(color: Color(hex: plate.colorHex), showFace: true)
                                .frame(width: 30, height: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plate.label).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.65)
                                Text("库存 \(plate.availablePairs ?? 1) 对").font(.caption2).foregroundStyle(.secondary)
                                    .lineLimit(1).minimumScaleFactor(0.6)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            plateDecrease(plate)
                            Text("\(store.selected[plate.id, default: 0])")
                                .font(.caption.weight(.semibold)).monospacedDigit()
                                .frame(minWidth: 20).fixedSize().layoutPriority(2)
                            plateIncrease(plate)
                        }
                        .padding(.horizontal, 4).frame(minHeight: 60)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var innerSessionPanel: some View {
        return VStack(alignment: .leading, spacing: 10) {
            TrainingPlanControls(note: $note, reps: $reps, prominentStart: true).font(.subheadline)
            if store.activePlan != nil {
                Stepper("每组 \(reps) 次", value: $reps, in: 1...999).font(.subheadline)
                HStack {
                    TextField("动作或备注", text: $note).textFieldStyle(.roundedBorder)
                    Menu {
                        ForEach(TrainingStore.standardActions, id: \.self) { name in
                            Button(name) { note = name }
                        }
                    } label: { Image(systemName: "list.bullet").frame(width: 44, height: 44) }
                    .accessibilityLabel("选择动作")
                }
                Button(action: record) {
                    Label("记录这一组", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity)
                }.buttonStyle(TrainingActionStyle(kind: .primary))
                HStack {
                    Button("复用上一组", action: reuse).disabled(store.sets.isEmpty)
                    Spacer()
                    Button("清空装片") { store.selected.removeAll() }
                }.font(.caption)
            }
            Divider()
            HStack {
                Label("组间休息", systemImage: "timer").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("休息时长", selection: $duration) {
                    Text("60 秒").tag(60); Text("90 秒").tag(90)
                    Text("2 分钟").tag(120); Text("3 分钟").tag(180)
                }.labelsHidden()
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let seconds = pausedSeconds ?? deadline.map({ max(0, Int(ceil($0.timeIntervalSince(context.date)))) }) {
                    HStack {
                        Text(seconds == 0 ? "休息结束" : String(format: "休息 %02d:%02d", seconds / 60, seconds % 60))
                        Spacer()
                        if let paused = pausedSeconds {
                            Button("继续") { deadline = Date().addingTimeInterval(Double(paused)); pausedSeconds = nil }
                        }
                        Button("关闭") { deadline = nil; pausedSeconds = nil }
                    }.font(.caption).foregroundStyle(TrainingTheme.teal)
                } else {
                    Text("记录后自动开始").font(.caption).foregroundStyle(.secondary)
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 14, content: content).padding(16)
        }
    }

    private func dashboardContent() -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 14) {
                    if let fold = verticalFold(in: geometry) {
                        // 折叠屏双栏必须以系统提供的折痕为界；不要用等宽或最大内容宽度重新居中。
                        HStack(alignment: .top, spacing: 0) {
                            VStack(spacing: 14) {
                                weightCard
                                platesCard(grid: fold.minX - 16 >= 260 && !dynamicTypeSize.isAccessibilitySize)
                                calendarCard
                            }
                                .frame(width: max(0, fold.minX - 16))
                            Color.clear.frame(width: fold.width, height: 0)
                            VStack(spacing: 14) { expandedPlanCard; recordCard; restCard; overviewCard; toolsButton }
                                .frame(width: max(0, geometry.size.width - fold.maxX - 16))
                        }
                        .padding(.horizontal, 16)
                    } else if geometry.size.width >= 560 && horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 14) {
                                weightCard
                                platesCard(grid: (geometry.size.width - 46) / 2 >= 260 && !dynamicTypeSize.isAccessibilitySize,
                                           gridItemHeight: min(105, max(72, geometry.size.height * 0.12)))
                                calendarCard
                                overviewCard
                            }
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 14) {
                                expandedPlanCard
                                recordCard
                                restCard
                                toolsButton
                            }
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        weightCard
                        platesCard(grid: false)
                        if !usesCompactMenu {
                            calendarCard
                            expandedPlanCard
                            recordCard
                            restCard
                            overviewCard
                            toolsButton
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, verticalFold(in: geometry) == nil ? 16 : 0)
                .frame(maxWidth: verticalFold(in: geometry) == nil ? 1100 : .infinity)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func verticalFold(in geometry: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            return geometry.reservedRegions(kind: .division).map(\.frame).first {
                $0.height > $0.width && $0.minX > 16 && $0.maxX < geometry.size.width - 16
            }
        }
        return nil
    }

    private var calendarCard: some View {
        let daySets = store.sets.filter { Calendar.current.isDate($0.date, inSameDayAs: calendarDate) }
        let volume = daySets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return VStack(alignment: .leading, spacing: 10) {
            Label("训练日历", systemImage: "calendar").font(.headline)
                .labelStyle(TealIconLabelStyle())
            TrainingCalendar(selectedDate: $calendarDate, sets: store.sets)
            HStack {
                Text("\(daySets.count) 组 · \(volume.formattedWeight) kg")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                NavigationLink { DayHistoryView(date: calendarDate) } label: {
                    Label("查看记录", systemImage: "list.bullet")
                }
                TrainingShareButton(date: calendarDate, compact: true)
            }
        }.trainingCard()
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("当前总重量", systemImage: "scalemass").font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(store.total.formattedWeight).font(.system(size: 45, weight: .bold, design: .rounded)).monospacedDigit()
                Text("kg").font(.headline)
                Spacer()
                Button(action: showCalculator) { Label("自动配重", systemImage: "equal.circle") }
                    .font(.subheadline).foregroundStyle(TrainingTheme.accent)
            }.foregroundStyle(TrainingTheme.teal)
            BarbellView(plates: store.plates, selected: store.selected).frame(height: 68)
            Text("杆重 \(store.barWeight.formattedWeight) kg · 两侧对称")
                .font(.caption).foregroundStyle(.secondary)
        }.trainingCard()
    }

    private func platesCard(grid: Bool, gridItemHeight: CGFloat = 0) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("调整装片", systemImage: "circle.grid.2x2").font(.headline)
                    .labelStyle(TealIconLabelStyle())
                Spacer()
                Button("管理", action: showTools).font(.subheadline)
            }
            if store.plates.isEmpty {
                Text("还没有杠铃片规格，请到工具中添加。 ").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                WeightStepControls()
            }
            if grid {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(store.plates.sorted { $0.kilograms > $1.kilograms }) { plate in
                        plateGridItem(plate, minHeight: gridItemHeight)
                    }
                }
            } else {
                ForEach(store.plates.sorted { $0.kilograms > $1.kilograms }) { plate in
                    plateRow(plate)
                }
            }
        }.trainingCard()
    }

    private func plateRow(_ plate: Plate) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: plate.colorHex)).frame(width: 10, height: 10)
            Text(plate.label).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
            plateDecrease(plate)
            Text("\(store.selected[plate.id, default: 0]) 对").monospacedDigit().frame(minWidth: 40)
            plateIncrease(plate)
        }.buttonStyle(.plain)
    }

    private func plateGridItem(_ plate: Plate, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: plate.colorHex)).frame(width: 10, height: 10)
                Text(plate.label).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            HStack(spacing: 0) {
                plateDecrease(plate)
                Text("\(store.selected[plate.id, default: 0]) 对").monospacedDigit()
                    .font(.caption).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity)
                plateIncrease(plate)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 4).padding(.top, 8).padding(.bottom, 2)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func plateDecrease(_ plate: Plate) -> some View {
        Button { store.selected[plate.id, default: 0] -= 1 } label: {
            Image(systemName: "minus.circle").frame(width: 44, height: 44)
        }.disabled(store.selected[plate.id, default: 0] == 0)
            .accessibilityLabel("减少一对 \(plate.label)")
    }

    private func plateIncrease(_ plate: Plate) -> some View {
        Button { store.addPlate(plate) } label: {
            Image(systemName: "plus.circle").frame(width: 44, height: 44)
        }.disabled(!store.canAddPlate(plate))
            .accessibilityLabel("增加一对 \(plate.label)")
    }

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("记录训练", systemImage: "figure.strengthtraining.traditional").font(.headline)
            if store.activePlan != nil {
                Stepper("每组次数：\(reps) 次", value: $reps, in: 1...999)
                TextField("动作或备注", text: $note).textFieldStyle(.roundedBorder)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(TrainingStore.standardActions, id: \.self) { name in
                            Button(name) { note = name }.buttonStyle(TrainingTagStyle(selected: note == name))
                        }
                    }
                }
                ActionProgressView(action: note)
                Button(action: record) { Label("记录这一组", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(TrainingActionStyle(kind: .primary))
                HStack {
                    Button("复用上一组", action: reuse).disabled(store.sets.isEmpty)
                    Spacer()
                    Button("清空装片") { store.selected.removeAll() }.foregroundStyle(.secondary)
                }.font(.subheadline)
            } else {
                Text("请先设置目标组数并开始训练。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }.trainingCard()
    }

    private var restCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("组间休息", systemImage: "timer").font(.headline)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let seconds = pausedSeconds ?? deadline.map({ max(0, Int(ceil($0.timeIntervalSince(context.date)))) }) {
                        Text(seconds == 0 ? "休息结束" : String(format: "%02d:%02d", seconds / 60, seconds % 60))
                            .monospacedDigit().foregroundStyle(TrainingTheme.teal)
                    } else { Text("记录后自动开始").font(.caption).foregroundStyle(.secondary) }
                }
            }
            HStack {
                Picker("休息时长", selection: $duration) {
                    Text("60 秒").tag(60); Text("90 秒").tag(90)
                    Text("2 分钟").tag(120); Text("3 分钟").tag(180)
                }
                Spacer()
                if let seconds = pausedSeconds {
                    Button("继续") { deadline = Date().addingTimeInterval(Double(seconds)); pausedSeconds = nil }
                }
                if deadline != nil || pausedSeconds != nil {
                    Button("关闭") { deadline = nil; pausedSeconds = nil }
                }
            }.font(.subheadline)
        }.trainingCard()
    }

    private var expandedPlanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("训练计划", systemImage: "checklist").font(.headline)
                .labelStyle(TealIconLabelStyle())
            TrainingPlanControls(note: $note, reps: $reps)
        }.trainingCard()
    }

    private var overviewCard: some View {
        Button(action: showOverview) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Label("今日训练", systemImage: "chart.bar.fill").font(.headline)
                    let today = store.sets.filter { Calendar.current.isDateInToday($0.date) }
                    Text("\(today.count) 组 · \(today.reduce(0.0) { $0 + $1.weight * Double($1.reps) }.formattedWeight) kg 总吨数")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let latest = today.max(by: { $0.date < $1.date }) {
                        Text("最近一组：\(latest.note?.isEmpty == false ? latest.note! : "未分类") · \(latest.weight.formattedWeight) kg × \(latest.reps) 次")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).trainingCard()
    }

    private var toolsButton: some View {
        Button(action: showTools) {
            Label("工具与设置", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity)
        }.buttonStyle(TrainingActionStyle(kind: .secondary))
    }
}

private extension View {
    func trainingCard() -> some View {
        self.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(TrainingTheme.card, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct TealIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon.foregroundStyle(TrainingTheme.teal)
            configuration.title
        }
    }
}

