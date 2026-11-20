import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct TrainingPlanControls: View {
    @EnvironmentObject private var store: TrainingStore
    @AppStorage("trainingPlanTarget") private var target = 10
    @State private var confirmingEnd = false
    @State private var showStart = false
    @State private var draftReps = 10
    @State private var draftActions: [TrainingPlanAction] = []
    @Binding var note: String
    @Binding var reps: Int
    var compact = false
    var prominentStart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let plan = store.activePlan {
                HStack {
                    Text(compact ? "已完成 \(store.planProgressCount)/目标 \(plan.target) 组" : "训练计划  \(store.planProgressCount) / \(plan.target) 组")
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if compact {
                        Button("结束训练") { TrainingSound.tap(); TrainingFeedback.adjustHaptic(); confirmingEnd = true }
                            .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 14))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color(red: 0.24, green: 0.13, blue: 0.29), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.purple.opacity(0.8), lineWidth: 1))
                    } else {
                        Spacer()
                        Button("结束训练") { TrainingSound.tap(); confirmingEnd = true }
                    }
                }
                if let actions = plan.actions {
                    if compact, let action = actions.first(where: { TrainingStore.actionKey($0.name) == TrainingStore.actionKey(note) }) {
                        Text("\(action.name)：\(store.completedCount(for: action))/\(action.target) 组")
                            .font(.caption).lineLimit(1)
                    } else if !compact {
                        ForEach(actions) { action in
                            Text("\(action.name)：\(store.completedCount(for: action))/\(action.target) 组")
                                .font(.caption).lineLimit(1)
                        }
                    }
                }
                if store.planIsComplete {
                    Text("已完成 · 可继续记录训练").font(.caption).foregroundStyle(.green)
                }
            } else {
                let todayCount = store.sets.filter { Calendar.current.isDateInToday($0.date) }.count
                if todayCount >= target {
                    Text("今日已完成 \(todayCount) / \(target) 组")
                        .font(compact ? .caption : .subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else if todayCount > 0 && !compact {
                    Text("今日已记录 \(todayCount) 组 · 当前目标 \(target) 组")
                        .font(.caption).foregroundStyle(.secondary)
                }
                startButton(todayCount: todayCount)
                    .frame(maxWidth: prominentStart ? .infinity : nil)
                    .buttonStyle(TrainingActionStyle(kind: prominentStart ? .primary : .secondary))
            }
        }
        .sheet(isPresented: $showStart) {
            TrainingPlanEntryForm(actions: $draftActions, defaultReps: draftReps) {
                guard let first = draftActions.first else { return }
                target = first.target
                note = first.name
                reps = first.reps ?? draftReps
                draftActions.forEach { store.rememberCustomAction($0.name) }
                store.activePlan = TrainingPlan(target: draftActions.reduce(0) { $0 + $1.target }, startedAt: Date(), actions: draftActions)
                showStart = false
                TrainingSound.confirm()
            }
            .presentationDetents(compact ? [.fraction(0.5)] : [.large])
        }
        .onChange(of: target) { _ in TrainingSound.adjust() }
        .alert("结束本次训练？", isPresented: $confirmingEnd) {
            Button("结束训练", role: .destructive) { TrainingSound.confirm(); if compact { TrainingFeedback.confirmHaptic() }; store.finishTraining() }
            Button("继续训练", role: .cancel) {}
        } message: { Text("已记录的训练数据会保留。") }
    }
    private func startButton(todayCount: Int) -> some View {
        Button(todayCount >= target ? "开始新训练" : "开始训练") {
            TrainingSound.tap()
            if compact { TrainingFeedback.adjustHaptic() }
            draftReps = reps
            draftActions = [TrainingPlanAction(name: note, target: target, reps: reps)]
            showStart = true
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }
}

struct TrainingPlanEntryForm: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TrainingStore
    @Binding var actions: [TrainingPlanAction]
    let defaultReps: Int
    let confirm: () -> Void

    private var valid: Bool {
        let names = actions.map { TrainingStore.actionKey($0.name) }
        return !names.isEmpty && names.allSatisfy { !$0.isEmpty } && Set(names).count == names.count
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach($actions) { $item in
                    Section {
                        TextField("选择或输入动作", text: $item.name).foregroundColor(.black)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(TrainingStore.standardActions + store.customActions, id: \.self) { name in
                                    Button(name) { item.name = name }
                                        .buttonStyle(TrainingTagStyle(selected: item.name == name))
                                }
                            }
                        }
                        Stepper("目标组数：\(item.target) 组", value: $item.target, in: 1...999)
                            .foregroundColor(.black)
                        Stepper("每组次数：\(item.reps ?? defaultReps) 次", value: Binding(
                            get: { item.reps ?? defaultReps },
                            set: { item.reps = $0 }
                        ), in: 1...999).foregroundColor(.black)
                        if actions.count > 1 {
                            Button("移除此动作", role: .destructive) { actions.removeAll { $0.id == item.id } }
                        }
                    } header: { Text("动作及目标组数").foregroundColor(.black.opacity(0.7)) }
                }
                Button("添加动作") { actions.append(TrainingPlanAction(name: "", target: 1, reps: defaultReps)) }
                    .disabled(actions.count >= 20)
                if !valid {
                    Text("请填写每个动作，且不要重复添加同一动作。")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(TrainingModalButtonStyle())
            .tint(TrainingTheme.accent)
            .navigationTitle("开始训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.buttonStyle(TrainingModalButtonStyle()) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始训练") { confirm() }.buttonStyle(TrainingModalButtonStyle(confirm: true)).disabled(!valid)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

struct TrainingEntryForm: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TrainingStore
    let title: String
    @Binding var action: String
    @Binding var reps: Int
    var target: Binding<Int>? = nil
    let confirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("选择或输入动作", text: $action)
                        .foregroundColor(.black)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(NSOrderedSet(array: (store.activePlan?.actions?.map { $0.name } ?? []) + TrainingStore.standardActions + store.customActions)) as? [String] ?? [], id: \.self) { name in
                                Button(name) {
                                    action = name
                                    if let planned = store.activePlan?.actions?.first(where: { TrainingStore.actionKey($0.name) == TrainingStore.actionKey(name) }), let plannedReps = planned.reps {
                                        reps = plannedReps
                                    }
                                }
                                    .buttonStyle(TrainingTagStyle(selected: action == name))
                            }
                        }
                    }
                } header: {
                    Text("动作").foregroundColor(.black.opacity(0.7))
                }
                Section {
                    if let target = target {
                        Stepper("目标组数：\(target.wrappedValue) 组", value: target, in: 1...999)
                            .foregroundColor(.black)
                    }
                    Stepper("每组次数：\(reps) 次", value: $reps, in: 1...999)
                        .foregroundColor(.black)
                } header: {
                    Text("训练设置").foregroundColor(.black.opacity(0.7))
                }
            }
            .foregroundStyle(.primary)
            .buttonStyle(TrainingModalButtonStyle())
            .tint(TrainingTheme.accent)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.buttonStyle(TrainingModalButtonStyle()) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(title) { confirm() }
                        .buttonStyle(TrainingModalButtonStyle(confirm: true))
                        .disabled(action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

struct TrainingCalendar: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var selectedDate: Date
    let sets: [TrainingSet]
    var compact = false
    var dayHeight: CGFloat? = nil
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private var calendar: Calendar { Calendar.current }
    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month), let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }.map { Optional($0) }
    }
    private var weekdays: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    var body: some View {
        VStack(spacing: compact ? 5 : 12) {
            HStack {
                Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44).contentShape(Rectangle()) }.accessibilityLabel("上个月")
                Spacer()
                Text(month.formatted(.dateTime.year().month(.wide))).font(.headline)
                Spacer()
                Button { changeMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44).contentShape(Rectangle()) }.accessibilityLabel("下个月")
            }
            LazyVGrid(columns: columns, spacing: compact ? 2 : 8) {
                ForEach(weekdays.indices, id: \.self) { index in Text(weekdays[index]).font(.caption).lineLimit(1).minimumScaleFactor(0.65).foregroundStyle(.secondary) }
                ForEach(days.indices, id: \.self) { index in
                    if let day = days[index] {
                        let types = trainingTypes(on: day)
                        let isSelected = calendar.isDate(selectedDate, inSameDayAs: day)
                        Button { selectedDate = day } label: {
                            VStack(spacing: 2) {
                                VStack(spacing: 1) {
                                    if isSelected && (!compact || dayHeight != nil) {
                                        let avatarSize: CGFloat = dayHeight.map { min(52, max(20, $0 - 35)) } ?? (horizontalSizeClass == .regular ? 52 : 34)
                                        Image(types.isEmpty ? "CalendarRestDay" : "CalendarTrainingDay")
                                            .resizable().scaledToFit()
                                            .frame(width: avatarSize, height: avatarSize)
                                            .scaleEffect(types.isEmpty ? 1.1 : 1)
                                            .accessibilityHidden(true)
                                    } else if !compact && horizontalSizeClass == .compact {
                                        // 小屏所有日期预留头像高度，切换日期时不改变周行高度。
                                        Color.clear.frame(width: 34, height: 34)
                                            .accessibilityHidden(true)
                                    }
                                    Text("\(calendar.component(.day, from: day))")
                                        .font(.body).lineLimit(1).minimumScaleFactor(0.65)
                                        .foregroundStyle(isSelected ? TrainingTheme.accent : Color.primary)
                                }
                                .frame(maxWidth: .infinity, minHeight: compact ? 24 : 34)
                                Text(types.joined(separator: "、"))
                                    .font(.system(size: 9))
                                    .foregroundStyle(TrainingTheme.accent)
                                    .lineLimit(2).minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity, minHeight: compact ? 12 : 22, alignment: .top)
                            }.frame(maxWidth: .infinity, minHeight: max(44, dayHeight ?? 0)).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted))\(types.isEmpty ? "" : "，" + types.joined(separator: "、"))")
                    } else { Color.clear.frame(height: dayHeight ?? (compact ? 36 : 58)) }
                }
            }
        }.padding(.vertical, compact ? 2 : 8)
    }

    private func trainingTypes(on day: Date) -> [String] {
        var types: [String] = []
        for set in sets where calendar.isDate(set.date, inSameDayAs: day) {
            let note = (set.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let type = note.isEmpty ? "未分类" : note
            if !types.contains(type) { types.append(type) }
        }
        return types
    }

    private func changeMonth(_ offset: Int) {
        if let next = calendar.date(byAdding: .month, value: offset, to: month) { month = next }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupSection: View {
    @EnvironmentObject private var store: TrainingStore
    @State private var document = BackupDocument(data: Data())
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingBackup: TrainingBackup?
    @State private var confirmRestore = false
    @State private var message: String?

    var body: some View {
        Section("数据备份") {
            Button("导出备份") {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    document = BackupDocument(data: try encoder.encode(store.backup()))
                    exporting = true
                } catch { message = "无法生成备份，请重试。" }
            }
            Button("恢复备份") { importing = true }
            Text("备份包含规格、杆重、训练记录、训练时段、已关联的健康消耗和当前计划。恢复会覆盖当前数据。") .font(.footnote).foregroundStyle(.secondary)
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "蛛莉铁馆备份") { result in
            if case .failure = result { message = "导出失败，请重试。" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let backup = try JSONDecoder().decode(TrainingBackup.self, from: data)
                guard backup.isValid else { message = "备份内容无效或版本不受支持。"; return }
                pendingBackup = backup
                confirmRestore = true
            } catch { message = "无法读取备份，请选择有效的备份文件。" }
        }
        .alert("恢复备份？", isPresented: $confirmRestore) {
            Button("覆盖并恢复", role: .destructive) {
                if let backup = pendingBackup { store.restore(backup); pendingBackup = nil; message = "备份已恢复。" }
            }
            Button("取消", role: .cancel) { pendingBackup = nil }
        } message: { Text("将覆盖当前规格、杆重和全部训练记录。建议先导出当前数据。") }
        .alert("数据备份", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}

struct ProvisioningStatusSection: View {
    private let expiration = Self.profileExpiration()
    @AppStorage("expiryReminderEnabled") private var reminderEnabled = false
    @State private var reminderMessage: String?
    private let reminderID = "provisioning-expiration-reminder"

    var body: some View {
        Section("开发描述文件") {
            if let expiration = expiration {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let remaining = expiration.timeIntervalSince(context.date)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(remaining > 0 ? "剩余有效期" : "已到期").font(.headline)
                            Spacer()
                            if remaining > 0 {
                                let minutes = Int(ceil(remaining / 60))
                                Text("\(minutes / 1440) 天 \((minutes % 1440) / 60) 小时 \(minutes % 60) 分")
                                    .monospacedDigit().foregroundStyle(remaining <= 86400 ? .orange : .secondary)
                            }
                        }
                        Text("到期时间：\(expiration.formatted(date: .numeric, time: .shortened))")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if remaining > 0 && remaining <= 86400 {
                            Text("即将到期，请连接 Xcode 重新安装。") .font(.footnote).foregroundStyle(.orange)
                        }
                    }.padding(.vertical, 3)
                }
                if reminderEnabled {
                    Button("关闭到期提醒") {
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
                        reminderEnabled = false
                        reminderMessage = "到期提醒已关闭。"
                    }
                } else {
                    Button("开启到期提醒") { Task { await enableReminder(for: expiration) } }
                }
                Text("开启后会在到期前 24 小时发送本机通知；重新安装后请打开应用更新提醒。") .font(.footnote).foregroundStyle(.secondary)
                Text("仅显示描述文件的到期时间，实际运行还受签名和设备设置影响。") .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("当前无法获取描述文件到期时间。") .foregroundStyle(.secondary)
                Text("模拟器或部分安装方式可能没有可读取的描述文件。") .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .task {
            if reminderEnabled {
                if let expiration = expiration { await scheduleReminder(for: expiration, showMessage: false) }
                else { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID]) }
            }
        }
        .alert("到期提醒", isPresented: Binding(get: { reminderMessage != nil }, set: { if !$0 { reminderMessage = nil } })) {
            Button("好", role: .cancel) { reminderMessage = nil }
        } message: { Text(reminderMessage ?? "") }
    }

    @MainActor
    private func enableReminder(for expiration: Date) async {
        guard expiration > Date() else { reminderMessage = "描述文件已到期，请先重新安装应用。"; return }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            guard granted else { reminderMessage = "通知权限未开启，请在 iPhone 设置中允许蛛莉铁馆发送通知。"; return }
            reminderEnabled = true
            await scheduleReminder(for: expiration, showMessage: true)
        } catch { reminderMessage = "无法开启通知，请稍后重试。" }
    }

    @MainActor
    private func scheduleReminder(for expiration: Date, showMessage: Bool) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            center.removePendingNotificationRequests(withIdentifiers: [reminderID])
            if showMessage { reminderMessage = "通知权限未开启，请在 iPhone 设置中允许蛛莉铁馆发送通知。" }
            return
        }
        guard expiration > Date() else {
            center.removePendingNotificationRequests(withIdentifiers: [reminderID])
            if showMessage { reminderMessage = "描述文件已到期，请先重新安装应用。" }
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "蛛莉铁馆即将到期"
        content.body = "开发描述文件即将到期，请连接 Xcode 重新安装。"
        content.sound = .default
        let reminderDate = expiration.addingTimeInterval(-86400)
        let delay = max(2, reminderDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
            if showMessage { reminderMessage = delay <= 2 ? "已开启提醒，描述文件将在 24 小时内到期。" : "已开启提醒，将在到期前 24 小时通知你。" }
        } catch { reminderEnabled = false; reminderMessage = "提醒设置失败，请稍后重试。" }
    }

    private static func profileExpiration() -> Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data.subdata(in: start.lowerBound..<end.upperBound), options: [], format: nil),
              let values = plist as? [String: Any] else { return nil }
        return values["ExpirationDate"] as? Date
    }
}

// iPhone Duo 内屏优先：根据可用空间排列日历与记录，折痕区域不放置操作。
struct InnerCalendarPage: View {
    @EnvironmentObject private var store: TrainingStore
    @Binding var selectedDate: Date
    @State private var editingSet: TrainingSet?
    @State private var selectedRecordID: UUID?
    @State private var deletingSet: TrainingSet?

    private var daySets: [TrainingSet] {
        store.sets.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= geometry.size.height {
                let fold = division(in: geometry)
                let gap: CGFloat = fold?.width ?? 12
                let left = fold.map { max(0, $0.minX - 12) } ?? max(0, (geometry.size.width - 36) / 2)
                let right = fold.map { max(0, geometry.size.width - $0.maxX - 12) } ?? left
                let height = max(0, geometry.size.height - 24)
                HStack(alignment: .top, spacing: 0) {
                    calendar(height: height).frame(width: left)
                    Color.clear.frame(width: gap)
                    records.frame(width: right, height: height)
                }.padding(12)
            } else {
                let availableHeight = max(0, geometry.size.height - 36)
                let calendarHeight = availableHeight * 0.56
                VStack(spacing: 12) {
                    calendar(height: calendarHeight)
                    records.frame(height: availableHeight - calendarHeight)
                }.padding(12)
            }

        }
        .onChange(of: selectedDate) { _ in selectedRecordID = nil }
        .sheet(item: $editingSet) { set in EditNoteView(set: set) }
        .alert("删除训练记录？", isPresented: Binding(get: { deletingSet != nil }, set: { if !$0 { deletingSet = nil } })) {
            Button("删除", role: .destructive) {
                if let id = deletingSet?.id { store.sets.removeAll { $0.id == id } }
                deletingSet = nil
            }
            Button("取消", role: .cancel) { deletingSet = nil }
        } message: { Text("删除后无法撤销。") }
    }

    private func calendar(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("训练日历", systemImage: "calendar").font(.headline)
            TrainingCalendar(selectedDate: $selectedDate, sets: store.sets, compact: true,
                             dayHeight: max(0, (height - 106) / 6))
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(TrainingTheme.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private var records: some View {
        let volume = daySets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                Spacer(minLength: 4)
                TrainingShareButton(date: selectedDate, compact: true)
            }
            Text("\(daySets.count) 组 · 训练量 \(volume.formattedWeight) kg")
                .font(.subheadline).foregroundStyle(.secondary)
            if daySets.isEmpty {
                Text("当天没有训练记录").font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(daySets) { set in
                            HStack(spacing: 0) {
                            Button { selectedRecordID = set.id; editingSet = set } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(set.note?.isEmpty == false ? set.note! : "未分类")
                                            .font(.subheadline.weight(.semibold)).lineLimit(1)
                                        Text(set.date.formatted(date: .omitted, time: .shortened))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 4)
                                    Text("\(set.weight.formattedWeight) kg × \(set.reps)")
                                        .font(.subheadline).lineLimit(1).minimumScaleFactor(0.7)
                                }.frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(TrainingRecordSelectionStyle(selected: selectedRecordID == set.id))
                            Button(role: .destructive) { deletingSet = set } label: {
                                Image(systemName: "trash").frame(width: 44, height: 44)
                            }.buttonStyle(.plain).accessibilityLabel("删除这条训练记录")
                            }
                        }
                    }
                }
            }
        }
        .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TrainingTheme.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private func division(in geometry: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            return geometry.reservedRegions(kind: .division).map(\.frame).first {
                $0.height > $0.width && $0.minX > 12 && $0.maxX < geometry.size.width - 12
            }
        }
        return nil
    }
}
