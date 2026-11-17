import SwiftUI

struct FoldedTrainingHUD: View {
    @EnvironmentObject private var store: TrainingStore
    @Binding var note: String
    let reps: Int
    let totalWeight: Double
    let barWeight: Double
    let todayCount: Int
    let remainingSeconds: Int?
    let totalDuration: Int
    let isPaused: Bool
    let informationY: CGFloat

    private let neon = Color(red: 0.74, green: 1, blue: 0.12)
    private var modes: [String] { TrainingStore.standardActions + store.customActions }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let panelWidth = min(max(size.width * 0.20, 100), 170)
            let buttonHeight = min(max(size.height * 0.075, 23), 29)
            let topCenterY = max(buttonHeight, 44) / 2 + 8
            let modesWidth = min(size.width * 0.37, max(0, size.width / 2 - 52))
            ZStack(alignment: .topLeading) {
                modeButtons(height: buttonHeight)
                    .frame(width: modesWidth, height: min(size.height * 0.45, CGFloat((modes.count + 4) / 5) * (buttonHeight + 3)), alignment: .topLeading)
                    .offset(x: 8, y: topCenterY - buttonHeight / 2)
                    .zIndex(1)

                fightHUD(width: size.width)
                    .allowsHitTesting(false)
                    .position(x: size.width / 2, y: topCenterY)

                stats(width: panelWidth)
                    .position(x: size.width - panelWidth / 2 - 10,
                              y: size.height * (informationY < 0.5 ? 0.40 : 0.75))
            }
        }
    }

    @ViewBuilder private func modeButtons(height: CGFloat) -> some View {
        modeButtonRow(height: height)
    }

    private func modeButtonRow(height: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 5), spacing: 3) {
                ForEach(modes, id: \.self) { mode in
                    modeButton(mode, height: height, roundedLeading: mode == modes.first, slanted: true)
                }
            }
        }
    }

    private func modeButton(_ name: String, height: CGFloat, roundedLeading: Bool, slanted: Bool) -> some View {
        let selected = TrainingStore.actionKey(note) == TrainingStore.actionKey(name)
        let shape = ModeButtonShape(roundedLeading: roundedLeading, slanted: slanted)
        return Button { TrainingFeedback.tap(); note = name } label: {
            HStack {
                Spacer(minLength: 0)
                Text(name).font(.custom("ZCOOLQingKeHuangYou-Regular", size: max(13, height * 0.53)))
                    .lineLimit(1).minimumScaleFactor(0.5)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .modifier(ModeGlassStyle(shape: shape, selected: selected))
            .overlay(shape.stroke(selected ? neon : Color(red: 0.72, green: 0.28, blue: 0.88), lineWidth: selected ? 1.5 : 1))
            .shadow(color: selected ? neon.opacity(0.6) : Color.purple.opacity(0.35), radius: selected ? 5 : 2)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name)\(selected ? "，已选择" : "")")
        .accessibilityHint("选择动作会替换备注内容")
    }

    private func fightHUD(width: CGFloat) -> some View {
        let resting = (remainingSeconds ?? 0) > 0
        let clockWidth: CGFloat = 72
        let barWidth = max(0, width / 2 - clockWidth / 2 - 12)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 2) {
                Text(isPaused && resting ? "PAUSED" : "TIME")
                    .font(.custom("Orbitron-Regular", size: 7).weight(.black))
                Text(resting ? String(format: "%02d:%02d", (remainingSeconds ?? 0) / 60, (remainingSeconds ?? 0) % 60) : "--:--")
                    .font(.custom("Orbitron-Regular", size: 17).weight(.black))
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .foregroundStyle(.white)
            .frame(width: clockWidth, height: 40)
            .background(Color(red: 0.16, green: 0.02, blue: 0.24).opacity(0.9))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.purple, lineWidth: 2))
            .shadow(color: .purple, radius: 4)
            .position(x: width / 2, y: 20)

            VStack(spacing: 3) {
                fightBar(progress: store.activePlan.map { min(1, Double(store.planProgressCount) / Double($0.target)) } ?? 0, energy: false)
                    .frame(height: 13)
                    .shadow(color: store.celebrationID == nil ? .clear : .cyan, radius: 8)
                    .opacity(store.celebrationID == nil ? 1 : 0.55)
                    .animation(store.celebrationID == nil ? .default : .easeInOut(duration: 0.3).repeatCount(5, autoreverses: true), value: store.celebrationID)
                fightBar(progress: resting && totalDuration > 0 ? min(1, max(0, 1 - Double(remainingSeconds ?? 0) / Double(totalDuration))) : 1, energy: true)
                    .frame(width: barWidth * 0.78, height: 9, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: barWidth)
            .position(x: width / 2 + clockWidth / 2 + barWidth / 2, y: 20)
        }
        .frame(width: width, height: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((store.activePlan.map { "训练计划 \(store.planProgressCount) / \($0.target) 组，" } ?? "未开始训练计划，") + (resting ? "休息剩余 \(remainingSeconds ?? 0) 秒，能量恢复 \(totalDuration > 0 ? Int((min(1, max(0, 1 - Double(remainingSeconds ?? 0) / Double(totalDuration))) * 100).rounded()) : 100)%\(isPaused ? "，已暂停" : "")" : "训练中，能量满格"))
    }

    private func fightBar(progress: Double, energy: Bool) -> some View {
        GeometryReader { geometry in
        ZStack(alignment: .leading) {
            Color(red: 0.12, green: 0.10, blue: 0.17)
            LinearGradient(
                    colors: energy ? [Color(red: 0.83, green: 1, blue: 0.24), Color(red: 0.22, green: 0.78, blue: 0.04)] : [.white, Color(red: 0.36, green: 0.72, blue: 1), Color(red: 0.15, green: 0.26, blue: 0.58)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: geometry.size.width * CGFloat(progress))
            if energy {
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { _ in
                        Spacer(minLength: 0)
                        Rectangle().fill(Color.black.opacity(0.65)).frame(width: 2)
                    }
                }
            }
        }
        .clipShape(HealthBarShape(reversed: true))
        .overlay(HealthBarShape(reversed: true).stroke(Color.white.opacity(0.9), lineWidth: 1.5))
        }
    }

    private func stats(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("TRAINING STATUS").font(.custom("Orbitron-Regular", size: 8).weight(.black)).foregroundStyle(neon)
            Text("\(totalWeight.formattedWeight) kg")
                .font(.custom("Orbitron-Regular", size: 19).weight(.black)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
            Text("杆重 \(barWeight.formattedWeight) kg")
            Text("每组 \(reps) 次  ·  今日 \(todayCount) 组")
        }
        .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 12))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(Color(red: 0.08, green: 0.02, blue: 0.17).opacity(0.86))
        .overlay(Rectangle().stroke(Color.purple.opacity(0.9), lineWidth: 1))
        .frame(width: width)
    }
}

private struct ModeGlassStyle: ViewModifier {
    let shape: ModeButtonShape
    let selected: Bool

    func body(content: Content) -> some View {
        content.background(
            LinearGradient(
                colors: selected
                    ? [Color(red: 0.20, green: 0.34, blue: 0.12), Color(red: 0.06, green: 0.12, blue: 0.07)]
                    : [Color(red: 0.24, green: 0.13, blue: 0.29), Color(red: 0.08, green: 0.05, blue: 0.12)],
                startPoint: .top, endPoint: .bottom
            ), in: shape
        )
    }
}

private struct ModeButtonShape: Shape {
    let roundedLeading: Bool
    let slanted: Bool

    func path(in rect: CGRect) -> Path {
        if !slanted {
            guard roundedLeading else { return Path(rect) }
            return Path(UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .bottomLeft],
                                     cornerRadii: CGSize(width: 14, height: 14)).cgPath)
        }
        let slant = min(rect.height * 0.28, rect.width * 0.16)
        var path = Path()
        path.move(to: CGPoint(x: slant + (roundedLeading ? 6 : 0), y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - slant, y: rect.maxY))
        path.addLine(to: CGPoint(x: roundedLeading ? 6 : 0, y: rect.maxY))
        if roundedLeading {
            path.addQuadCurve(to: CGPoint(x: 1, y: rect.maxY - 6), control: CGPoint(x: 0, y: rect.maxY))
            path.addLine(to: CGPoint(x: slant, y: rect.minY + 6))
            path.addQuadCurve(to: CGPoint(x: slant + 6, y: rect.minY), control: CGPoint(x: slant + 1, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}

private struct HealthBarShape: Shape {
    let reversed: Bool

    func path(in rect: CGRect) -> Path {
        let cut = min(rect.height * 0.65, rect.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: reversed ? cut : 0, y: 0))
        path.addLine(to: CGPoint(x: reversed ? rect.width : rect.width - cut, y: 0))
        path.addLine(to: CGPoint(x: reversed ? rect.width - cut : rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: reversed ? 0 : cut, y: rect.height))
        path.closeSubpath()
        return path
    }
}
