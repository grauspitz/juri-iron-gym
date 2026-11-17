import SwiftUI
import WidgetKit
import ActivityKit

private let ink = Color(red: 0.075, green: 0.06, blue: 0.11)
private let purple = Color(red: 0.65, green: 0.31, blue: 0.96)
private let lavender = Color(red: 0.76, green: 0.67, blue: 0.83)

struct TrainingEntry: TimelineEntry {
    let date: Date
    let snapshot: TrainingWidgetSnapshot?
}

struct TrainingProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrainingEntry { TrainingEntry(date: Date(), snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (TrainingEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainingEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }
    private func entry() -> TrainingEntry {
        let data = UserDefaults(suiteName: trainingAppGroup)?.data(forKey: "trainingWidgetSnapshot")
        let snapshot = data.flatMap { try? JSONDecoder().decode(TrainingWidgetSnapshot.self, from: $0) }
        return TrainingEntry(date: Date(), snapshot: snapshot)
    }
}

struct TrainingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrainingEntry
    private var snapshot: TrainingWidgetSnapshot? { entry.snapshot }
    private var isToday: Bool { snapshot.map { Calendar.current.isDateInToday($0.date) } ?? false }
    private var count: Int { isToday ? snapshot?.todayCount ?? 0 : 0 }
    private var volume: Double { isToday ? snapshot?.todayVolume ?? 0 : 0 }
    private var weekDays: Int { guard let snapshot = snapshot, Calendar.current.isDate(snapshot.date, equalTo: Date(), toGranularity: .weekOfYear) else { return 0 }; return snapshot.weekDays }
    private var planTarget: Int? { snapshot?.planTarget }
    private var planCount: Int { snapshot?.planCount ?? 0 }
    private var progress: Double { guard let target = planTarget, target > 0 else { return 0 }; return min(1, Double(planCount) / Double(target)) }
    private var records: [WidgetTrainingSet] {
        guard isToday, let snapshot = snapshot else { return [] }
        return snapshot.recordSets ?? snapshot.recordSet.map { [$0] } ?? []
    }
    private var volumeText: String { String(format: "%.2f", volume).replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression) }

    var body: some View {
        Group { if family == .systemSmall { small } else { medium } }
            .containerBackground(for: .widget) { ink }
    }
    private enum DisplayState { case idle, training, completed, recovery, record }
    private var displayState: DisplayState {
        if isToday && snapshot?.hasRecordToday == true { return .record }
        let planStartedToday = snapshot?.planStartedAt.map { Calendar.current.isDateInToday($0) } ?? false
        let isRecoveryDay: Bool = {
            guard count == 0, let last = snapshot?.lastTrainingDate,
                  let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return false }
            return Calendar.current.isDate(last, inSameDayAs: yesterday)
        }()
        if isRecoveryDay && !planStartedToday { return .recovery }
        if let target = planTarget, planCount < target { return .training }
        if count > 0 { return .completed }
        return .idle
    }
    private var statusText: String {
        switch displayState {
        case .idle: return "今天还没开练"
        case .training: return "训练中"
        case .completed: return planTarget == nil ? "今日已训练" : "训练完成"
        case .recovery: return "休息日 · 恢复中"
        case .record: return "今日破纪录"
        }
    }
    private var portrait: some View {
        let size: CGFloat = family == .systemSmall ? 58 : 82
        return Group {
            if displayState == .idle {
                Image(family == .systemSmall ? "WidgetPortraitSmall" : "WidgetPortrait")
                    .resizable().scaledToFill().frame(width: size, height: size).clipped()
            } else {
                GeometryReader { geometry in
                    let right: CGFloat = displayState == .recovery || displayState == .training ? 1 : 0
                    let bottom: CGFloat = displayState == .recovery || displayState == .record ? 1 : 0
                    Image("WidgetStates").resizable()
                        .frame(width: geometry.size.width * 2, height: geometry.size.height * 2)
                        .offset(x: -geometry.size.width * right, y: -geometry.size.height * bottom)
                }
                .frame(width: size, height: size).clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }
    private var gauge: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule().fill(purple).frame(width: geometry.size.width * progress)
                    .shadow(color: purple.opacity(0.45), radius: 4)
            }
        }.frame(height: 6)
    }
    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("JURI GYM").font(.custom("Orbitron-Regular", size: 10))
                Spacer()
                Image(systemName: "bolt.fill")
            }.foregroundStyle(lavender)
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                portrait
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(count) 组").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text(statusText).font(.system(size: 10)).foregroundStyle(lavender)
                    Text("\(volumeText) kg").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                }.lineLimit(1).minimumScaleFactor(0.7)
            }
            if let target = planTarget, displayState != .recovery {
                gauge
                Text("本次计划 \(planCount)/\(target) 组").font(.system(size: 10)).foregroundStyle(lavender).lineLimit(1)
            } else {
                Text("本周训练 \(weekDays) 天").font(.system(size: 10)).foregroundStyle(lavender)
            }
        }
    }
    private var widgetCyberTitle: some View {
        let teal = Color(red: 0.40, green: 0.88, blue: 0.87)
        let pink = Color(red: 1.0, green: 0.42, blue: 0.68)
        return HStack(spacing: 3) {
            Rectangle().fill(teal).frame(width: 2, height: 15).rotationEffect(.degrees(12))
            ZStack {
                Text("蛛莉铁馆").foregroundStyle(pink.opacity(0.65)).offset(x: 1, y: 0.7)
                Text("蛛莉铁馆").foregroundStyle(teal.opacity(0.65)).offset(x: -1, y: -0.7)
                Text("蛛莉铁馆").foregroundStyle(.white)
            }
            .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 17))
            .italic().shadow(color: teal.opacity(0.45), radius: 3)
            Rectangle().fill(pink).frame(width: 5, height: 2).offset(y: 5)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("蛛莉铁馆")
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    widgetCyberTitle
                    Text("/ TRAINING STATUS").font(.custom("Orbitron-Regular", size: 8))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 2)
                Text("TODAY").font(.custom("Orbitron-Regular", size: 9))

            }.foregroundStyle(lavender)
            HStack(spacing: 11) {
                portrait
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(statusText).font(.system(size: 12, weight: .medium)).foregroundStyle(lavender)
                        Spacer(minLength: 2)
                        Text("\(count) 组").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    }
                    if let target = planTarget, displayState != .recovery {
                        gauge
                        Text("本次计划 \(planCount)/\(target) 组").font(.system(size: 9)).foregroundStyle(lavender)
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(volumeText).font(.custom("Orbitron-Regular", size: 20)).foregroundStyle(.white)
                            .shadow(color: .cyan.opacity(0.5), radius: 3)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text("kg").font(.system(size: 10, weight: .semibold)).foregroundStyle(lavender)
                    }
                    if !records.isEmpty {
                        let columns = records.count > 2 ? 2 : 1
                        let rows = (records.count + columns - 1) / columns
                        let fontSize = min(10, max(5, 44 / CGFloat(rows)))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), alignment: .leading, spacing: 1) {
                            ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                                let weight = String(format: "%.2f", record.weight)
                                    .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
                                Text("🏆 \(record.action) \(weight)kg×\(record.reps)")
                                    .font(.system(size: fontSize, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1).minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityLabel("\(record.action) \(weight) 千克，\(record.reps) 次，新纪录")
                            }
                        }
                    }
                    HStack {
                        Text("今日训练量")
                        Spacer(minLength: 2)
                        Text("本周 \(weekDays) 天")
                    }.font(.system(size: 10)).foregroundStyle(lavender)
                }
            }
        }
    }

}

struct TrainingStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: trainingWidgetKind, provider: TrainingProvider()) { entry in TrainingWidgetView(entry: entry) }
            .configurationDisplayName("训练能量槽").description("查看今日训练和本次计划进度。")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RestActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            HStack {
                VStack(alignment: .leading) {
                    Text("蛛莉铁馆 · 组间休息").font(.custom("ZCOOLQingKeHuangYou-Regular", size: 14)).shadow(color: Color(red: 0.25, green: 0.95, blue: 1).opacity(0.85), radius: 1, x: -0.7, y: -0.5).shadow(color: Color(red: 1, green: 0.25, blue: 0.8).opacity(0.85), radius: 1, x: 0.8, y: 0.6).shadow(color: purple.opacity(0.8), radius: 4).foregroundStyle(lavender)
                    Text(context.state.action.isEmpty ? "当前训练" : context.state.action).font(.custom("ZCOOLQingKeHuangYou-Regular", size: 19)).shadow(color: Color(red: 0.25, green: 0.95, blue: 1).opacity(0.85), radius: 1, x: -0.7, y: -0.5).shadow(color: Color(red: 1, green: 0.25, blue: 0.8).opacity(0.85), radius: 1, x: 0.8, y: 0.6).shadow(color: purple.opacity(0.8), radius: 4)
                    Text("当前设置 \(context.state.weight, specifier: "%.2f") kg × \(context.state.reps) 次").font(.custom("ZCOOLQingKeHuangYou-Regular", size: 13)).shadow(color: Color(red: 0.25, green: 0.95, blue: 1).opacity(0.85), radius: 1, x: -0.7, y: -0.5).shadow(color: Color(red: 1, green: 0.25, blue: 0.8).opacity(0.85), radius: 1, x: 0.8, y: 0.6).shadow(color: purple.opacity(0.8), radius: 4)
                }
                Spacer()
                restTime(context.state).font(.custom("Orbitron-Regular", size: 22)).shadow(color: Color.cyan.opacity(0.95), radius: 1).shadow(color: Color.cyan.opacity(0.85), radius: 4).monospacedDigit()
            }.padding().activityBackgroundTint(ink).activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text("组间休息").font(.custom("ZCOOLQingKeHuangYou-Regular", size: 14)).shadow(color: Color(red: 0.25, green: 0.95, blue: 1).opacity(0.85), radius: 1, x: -0.7, y: -0.5).shadow(color: Color(red: 1, green: 0.25, blue: 0.8).opacity(0.85), radius: 1, x: 0.8, y: 0.6).shadow(color: purple.opacity(0.8), radius: 4).foregroundStyle(lavender) }
                DynamicIslandExpandedRegion(.trailing) { restTime(context.state).font(.custom("Orbitron-Regular", size: 14)).shadow(color: Color.cyan.opacity(0.95), radius: 1).shadow(color: Color.cyan.opacity(0.85), radius: 4).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) { Text("\(context.state.action) · 当前设置 \(context.state.weight, specifier: "%.2f") kg × \(context.state.reps) 次").font(.custom("ZCOOLQingKeHuangYou-Regular", size: 13)).shadow(color: Color(red: 0.25, green: 0.95, blue: 1).opacity(0.85), radius: 1, x: -0.7, y: -0.5).shadow(color: Color(red: 1, green: 0.25, blue: 0.8).opacity(0.85), radius: 1, x: 0.8, y: 0.6).shadow(color: purple.opacity(0.8), radius: 4) }
            } compactLeading: { Image(systemName: "dumbbell.fill").foregroundStyle(purple) }
            compactTrailing: { restTime(context.state).font(.custom("Orbitron-Regular", size: 10)).shadow(color: Color.cyan.opacity(0.95), radius: 1).shadow(color: Color.cyan.opacity(0.85), radius: 4).monospacedDigit() }
            minimal: { Image(systemName: "timer").foregroundStyle(purple) }
        }
    }
    @ViewBuilder private func restTime(_ state: RestActivityAttributes.ContentState) -> some View {
        if let seconds = state.pausedSeconds { Text(String(format: "%02d:%02d", seconds / 60, seconds % 60)) }
        else if let deadline = state.deadline { Text(timerInterval: Date.distantPast...deadline, countsDown: true).frame(maxWidth: 75) }
        else { Text("--:--") }
    }
}

@main struct TrainingWidgets: WidgetBundle {
    var body: some Widget { TrainingStatusWidget(); RestActivityWidget() }
}
