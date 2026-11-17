import SwiftUI
import UIKit

struct ActionProgressView: View {
    @EnvironmentObject private var store: TrainingStore
    let action: String
    var compact = false

    var body: some View {
        let records = store.actionSets(action)
        let latest = records.max { $0.date < $1.date }
        let best = records.max(by: TrainingStore.isLowerRecord)
        VStack(alignment: .leading, spacing: 4) {
            if let latest = latest, let best = best {
                Text("上次 \(latest.weight.formattedWeight) kg × \(latest.reps) 次 · \(latest.date.formatted(date: .abbreviated, time: .shortened))")
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text("\(compact && store.recordMessage != nil && TrainingStore.actionKey(action) == TrainingStore.actionKey(store.recordMessage?.components(separatedBy: " · ").first ?? "") ? "🏆 新纪录" : "最高") \(best.weight.formattedWeight) kg × \(best.reps) 次 · \(best.date.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(TrainingTheme.accent)
                    .lineLimit(1).minimumScaleFactor(0.5)
            } else {
                Text(action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "选择动作查看上次成绩" : "该动作暂无训练记录")
            }
            if !compact, let message = store.recordMessage, TrainingStore.actionKey(action) == TrainingStore.actionKey(message.components(separatedBy: " · ").first ?? "") {
                Label(message, systemImage: "trophy.fill").foregroundStyle(TrainingTheme.accent)
            }
        }
        .font(compact ? .custom("ZCOOLQingKeHuangYou-Regular", size: 14) : .caption)
        .lineLimit(compact ? 1 : nil)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrainingInsightsView: View {
    @EnvironmentObject private var store: TrainingStore
    private var actions: [String] {
        let standard = ["深蹲", "卧推", "硬拉", "推举", "划船"]
        let additional = Set(store.sets.map { TrainingStore.actionKey($0.note ?? "") })
            .subtracting(standard).filter { !$0.isEmpty }.sorted()
        return standard + additional
    }
    private var today: [TrainingSet] {
        store.sets.filter { Calendar.current.isDateInToday($0.date) }
    }
    private var volume: Double { today.reduce(0) { $0 + $1.weight * Double($1.reps) } }
    private var todayActions: [String] {
        Array(Set(today.map { TrainingStore.actionKey($0.note ?? "") }.filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        List {
            Section {
                Text("\(today.count) 组 · 总训练量 \(volume.formattedWeight) kg")
                if today.isEmpty {
                    Text("今天还没有训练记录").foregroundStyle(.secondary)
                } else {
                    ForEach(todayActions, id: \.self) { action in
                        let sets = today.filter { TrainingStore.actionKey($0.note ?? "") == action }
                        Text("\(action)  ·  \(sets.count) 组  ·  最高 \((sets.map(\.weight).max() ?? 0).formattedWeight) kg")
                    }
                    if today.contains(where: { TrainingStore.actionKey($0.note ?? "").isEmpty }) {
                        Text("未分类  ·  \(today.filter { TrainingStore.actionKey($0.note ?? "").isEmpty }.count) 组")
                    }
                }
            } header: {
                HStack {
                    Text("今日训练总结")
                    Spacer()
                    TrainingShareButton(date: Date())
                }.textCase(nil)
            }.listRowBackground(TrainingTheme.card)
            TrainingEnergySection().listRowBackground(TrainingTheme.card)
            Section("动作最高重量") {
                ForEach(actions, id: \.self) { action in
                    let best = store.actionSets(action).max(by: TrainingStore.isLowerRecord)
                    HStack {
                        Text(action)
                        Spacer()
                        if let best = best {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(best.weight.formattedWeight) kg × \(best.reps) 次")
                                Text(best.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        else { Text("暂无记录").foregroundStyle(.secondary) }
                    }
                }
                Text("按单组重量统计，重量相同时按次数比较；旧记录按照动作备注匹配。")
                    .font(.footnote).foregroundStyle(.secondary)
            }.listRowBackground(TrainingTheme.card)


        }
        .scrollContentBackground(.hidden)
        .background(TrainingBackground())
        .navigationTitle("训练中心")
    }

}

struct TrainingShareButton: View {
    @EnvironmentObject private var store: TrainingStore
    @AppStorage("energyBodyWeight") private var energyBodyWeight = ""
    @State private var shareImage: SharedTrainingImage?
    let date: Date
    var compact = false
    private var today: [TrainingSet] { store.sets.filter { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    private var volume: Double { today.reduce(0) { $0 + $1.weight * Double($1.reps) } }

    var body: some View {
        Button {
            if let image = TrainingShareRenderer.makeImage(store: store, date: date, energyBodyWeight: energyBodyWeight) {
                shareImage = SharedTrainingImage(image: image)
            }
        } label: {
            Label(compact ? "分享" : "分享卡片", systemImage: "square.and.arrow.up")
                .font(.subheadline.bold()).foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, compact ? 8 : 12).padding(.vertical, 7)
                .background(TrainingTheme.accent, in: Capsule())
        }
        .buttonStyle(.plain).disabled(today.isEmpty).opacity(today.isEmpty ? 0.5 : 1)
        .sheet(item: $shareImage) { item in TrainingSharePreview(image: item.image) }
    }
}

enum TrainingShareRenderer {
    @MainActor static func makeImage(store: TrainingStore, date: Date, energyBodyWeight: String) -> UIImage? {
        let today = store.sets.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let volume = today.reduce(0) { $0 + $1.weight * Double($1.reps) }
        let records = store.recordsBroken(on: date)
        let backgroundIndex = records.isEmpty ? Int.random(in: 1...12) : Int.random(in: 13...14)
        let name: String
        switch backgroundIndex {
        case 13: name = "ShareRecordBackground"
        case 14: name = "ShareRecordBackgroundAlternate"
        default: name = String(format: "ShareBackground%02d", backgroundIndex)
        }
        guard let background = UIImage(named: name) else { return nil }
        let sessions = store.completedTrainings.filter { Calendar.current.isDate($0.endedAt, inSameDayAs: date) }
        let weight = Double(energyBodyWeight.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sessionIDs = Set(sessions.map(\.id))
        var rows: [String] = []
        for record in records {
            if let previous = record.previous {
                let difference = record.current.weight - previous.weight
                let repsChange = difference == 0 ? " · 次数 +\(record.current.reps - previous.reps)" : ""
                rows.append("\(record.action) 破纪录 · 重量 +\(difference.formattedWeight) kg\(repsChange)")
            } else {
                rows.append("\(record.action) · 首次纪录")
            }
        }
        rows.append("\(today.count) 组 · 训练量 \(volume.formattedWeight) kg")
        var healthTotal = 0.0
        var estimateTotal = 0.0
        var healthCount = 0
        var estimateCount = 0
        var missingCount = 0
        for session in sessions {
            if let value = session.healthCalories {
                healthTotal += value
                healthCount += 1
            } else if let value = TrainingEnergy.estimate(session: session, weight: weight, sets: store.sets) {
                estimateTotal += value
                estimateCount += 1
            } else {
                missingCount += 1
            }
        }
        if healthCount + estimateCount > 0 {
            rows.append("已统计消耗：约 \(Int((healthTotal + estimateTotal).rounded())) 大卡")
        }
        if healthCount > 0 { rows.append("Apple 健康：\(Int(healthTotal.rounded())) 大卡（\(healthCount) 次）") }
        if estimateCount > 0 { rows.append("估算消耗：约 \(Int(estimateTotal.rounded())) 大卡（\(estimateCount) 次）") }
        if healthCount == 0 && estimateCount == 0 { rows.append("消耗：暂无数据") }
        if missingCount > 0 { rows.append("\(missingCount) 次训练消耗未计算") }
        if sessions.contains(where: { !Calendar.current.isDate($0.startedAt, inSameDayAs: date) }) {
            rows.append("跨日训练消耗按完整场次统计")
        }
        if today.contains(where: { set in set.planID.map { !sessionIDs.contains($0) } ?? true }) {
            rows.append("部分记录缺少已结束的训练时段，未计入消耗")
        }
        let orderedActions = Array(Set(today.map { TrainingStore.actionKey($0.note ?? "") })).sorted()
        for action in orderedActions {
            let matching = today.filter { TrainingStore.actionKey($0.note ?? "") == action }
            rows.append("\(action.isEmpty ? "未分类" : action) · \(matching.count) 组")
            let combinations = Dictionary(grouping: matching) { "\($0.weight.formattedWeight) kg × \($0.reps) 次" }
            for key in combinations.keys.sorted() {
                rows.append("  \(key) · \(combinations[key]?.count ?? 0) 组")
            }
        }
        let card = TrainingShareCard(rows: rows, background: background, backgroundIndex: backgroundIndex, date: date)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        return renderer.uiImage
    }
}

private struct TrainingShareCard: View {
    let rows: [String]
    let background: UIImage
    let backgroundIndex: Int
    let date: Date
    private let width: CGFloat = 640

    private var shareDate: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)年\(parts.month ?? 0)月\(parts.day ?? 0)日"
    }

    private var cardHeight: CGFloat { width * background.size.height / background.size.width }
    // Positions are tuned to the empty space in each bundled background image.
    private var paperWidth: CGFloat {
        min(basePaperWidth * 1.22, width - 32, max(0, (cardHeight - paperTop - 8) * 1122 / 1402))
    }
    private var basePaperWidth: CGFloat {
        switch backgroundIndex {
        case 1: return 230
        case 2: return 220
        case 3: return 190
        case 4: return 220
        case 5: return 220
        case 6: return 220
        case 7: return 240
        case 8: return 220
        case 9: return 230
        case 10: return 180
        case 11: return 240
        case 12: return 190
        default: return 220
        }
    }
    private var paperTop: CGFloat {
        switch backgroundIndex {
        case 2, 4, 8, 9: return 20
        case 3, 10, 12: return 18
        case 7, 11: return 24
        default: return 35
        }
    }
    private var paperHeight: CGFloat { paperWidth * 1402 / 1122 }
    private var textSize: CGFloat {
        let available = paperHeight - 82
        return min(18, available / CGFloat(rows.count + 3) / 1.3)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: background)
                .resizable().scaledToFit()
                .frame(width: width, height: cardHeight)
            ZStack(alignment: .topLeading) {
                Image("SharePaperPortrait")
                    .resizable().frame(width: paperWidth, height: paperHeight).opacity(0.82)
                VStack(alignment: .leading, spacing: min(2, textSize * 0.15)) {
                    Text(backgroundIndex >= 13 ? "蛛莉铁馆 · 新纪录" : "蛛莉铁馆 · 训练战报")
                        .font(.custom("BaoCanMouHuiTing-Regular", size: textSize * 1.2))
                    Text(shareDate)
                        .font(.custom("BaoCanMouHuiTing-Regular", size: textSize * 0.9))
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Text(row).font(.custom("BaoCanMouHuiTing-Regular", size: textSize))
                            .lineLimit(1).minimumScaleFactor(0.55)
                    }
                }
                .foregroundStyle(Color(red: 0.20, green: 0.13, blue: 0.19))
                .frame(width: paperWidth - 68, alignment: .leading)
                .padding(.leading, 39)
                .padding(.top, 44)
            }
            .frame(width: paperWidth, height: paperHeight)
            .shadow(color: .black.opacity(0.25), radius: 8, x: 2, y: 5)
            .padding(.trailing, 16).padding(.top, paperTop)
        }
        .frame(width: width, height: cardHeight).clipped()
    }
}

struct SharedTrainingImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct TrainingSharePreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    let image: UIImage

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button { showingShareSheet = true } label: {
                    Label("分享卡片", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TrainingActionStyle(kind: .primary))
            }
            .padding(8)
            .background(TrainingBackground())
            .navigationTitle("分享卡片预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
            .sheet(isPresented: $showingShareSheet) { TrainingShareSheet(image: image) }
        }
    }
}

private struct TrainingShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

