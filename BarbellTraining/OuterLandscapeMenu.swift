import SwiftUI

enum OuterLandscapeDestination: String, CaseIterable, Identifiable {
    case home, record, training, overview, tools
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .record: return "记录"
        case .training: return "训练"
        case .overview: return "概览"
        case .tools: return "工具"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .record: return "list.clipboard.fill"
        case .training: return "dumbbell.fill"
        case .overview: return "chart.bar.fill"
        case .tools: return "slider.horizontal.3"
        }
    }
}

struct OuterLandscapeMenu: View {
    @Binding var destination: OuterLandscapeDestination?
    @State private var highlighted: OuterLandscapeDestination?
    @State private var transition: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let width = max(60, geometry.size.width * 0.70 / 5)
            let height = max(0, min(geometry.size.height * 0.72, 210))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(OuterLandscapeDestination.allCases) { item in
                        menuButton(item, width: width, height: height)
                    }
                }
                .padding(.horizontal, 8)
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
        }
        .background(TrainingBackground())
        .onDisappear {
            transition?.cancel()
            transition = nil
            highlighted = nil
        }
    }

    private func menuButton(_ item: OuterLandscapeDestination, width: CGFloat, height: CGFloat) -> some View {
        let active = highlighted == item
        let shape = SlantedMenuShape()
        return Button {
            guard transition == nil else { return }
            TrainingSound.tap()
            withAnimation(.easeOut(duration: 0.16)) { highlighted = item }
            transition = Task { @MainActor in
                do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                transition = nil
                destination = item
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: item.symbol)
                    .font(.system(size: min(32, max(18, height * 0.20)), weight: .bold))
                Text(item.title)
                    .font(.custom("ZCOOLQingKeHuangYou-Regular", size: min(26, max(16, height * 0.16))))
                    .lineLimit(1).minimumScaleFactor(0.7)
                if active {
                    Text("SELECTED")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.cyan, in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .frame(width: width, height: height)
            .modifier(SlantedGlassStyle(active: active, shape: shape))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

private struct SlantedGlassStyle: ViewModifier {
    let active: Bool
    let shape: SlantedMenuShape

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            decorated(content.glassEffect(.clear.tint(active ? Color.cyan.opacity(0.20) : Color.purple.opacity(0.06)).interactive(), in: shape))
        } else {
            decorated(content.background(.ultraThinMaterial, in: shape))
        }
    }

    private func decorated<Content: View>(_ content: Content) -> some View {
        content
            .overlay {
                shape.fill(LinearGradient(colors: [Color.white.opacity(active ? 0.10 : 0.05), .clear, (active ? Color.cyan.opacity(0.08) : Color.purple.opacity(0.03))], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .allowsHitTesting(false)
            }
            .overlay {
                shape.stroke(LinearGradient(colors: active
                    ? [.cyan, .white.opacity(0.9), Color(red: 0.1, green: 0.55, blue: 1)]
                    : [.white.opacity(0.5), Color.purple.opacity(0.6), Color.cyan.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: active ? 2 : 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: active ? Color.cyan.opacity(0.8) : Color.purple.opacity(0.2), radius: active ? 9 : 3)
    }
}

private struct SlantedMenuShape: Shape {
    func path(in rect: CGRect) -> Path {
        let slant = min(rect.width * 0.16, 18)
        var path = Path()
        path.move(to: CGPoint(x: slant, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width - slant, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct OuterLandscapeCalendar: View {
    @Binding var selectedDate: Date
    let sets: [TrainingSet]
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var showLastWeek = false
    private var calendar: Calendar { Calendar.current }
    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        // 背景星期固定从周日开始，日期也保持相同顺序。
        let leading = calendar.component(.weekday, from: interval.start) - 1
        return Array(repeating: nil, count: leading) + range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: interval.start)
        }.map { Optional($0) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 20) {
                Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("上个月")
                Text(month.formatted(.dateTime.year().month(.wide))).font(.system(size: 25, weight: .bold))
                Button { changeMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("下个月")
                if days.count > 35 {
                    Button(showLastWeek ? "前五周" : "末周") { showLastWeek.toggle() }
                        .font(.system(size: 16, weight: .bold)).padding(8)
                        .background(Color.black.opacity(0.5), in: Capsule())
                }
            }
            .foregroundStyle(.white).shadow(color: .purple, radius: 4)
            .position(x: 545, y: 132)
            ForEach(0..<35, id: \.self) { position in
                let row = position / 7
                let column = position % 7
                let index = position + (showLastWeek && row == 4 ? 7 : 0)
                if index < days.count, let day = days[index] {
                    dayButton(day)
                        .position(x: 316 + CGFloat(column) * 76.5,
                                  y: 226 + CGFloat(row) * 63 - CGFloat(column) * 0.5)
                }
            }
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(day)
        let trained = sets.contains { calendar.isDate($0.date, inSameDayAs: day) }
        return Button { selectedDate = day } label: {
            ZStack {
                if selected {
                    RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.45))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.9), lineWidth: 2))
                        .frame(width: 67, height: 54)
                } else if today {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.8), lineWidth: 2)
                        .frame(width: 67, height: 54)
                }
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white).shadow(color: .black, radius: 3)
                    .offset(y: trained ? -5 : 0)
                if trained {
                    HanddrawnCheckmark()
                        .stroke(Color(red: 1, green: 0.25, blue: 0.7),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 38, height: 26)
                        .rotationEffect(.degrees(-8)).offset(x: 8, y: 12)
                        .shadow(color: .black.opacity(0.8), radius: 2)
                        .accessibilityHidden(true)
                }
            }.frame(width: 73, height: 58).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted))\(today ? "，今天" : "")\(trained ? "，有训练" : "")")
    }

    private func changeMonth(_ offset: Int) {
        if let next = calendar.date(byAdding: .month, value: offset, to: month) {
            month = next
            showLastWeek = false
        }
    }
}

private struct HanddrawnCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.54))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.35, y: rect.height * 0.85),
                          control: CGPoint(x: rect.width * 0.24, y: rect.height * 0.62))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.94, y: rect.height * 0.12),
                          control: CGPoint(x: rect.width * 0.58, y: rect.height * 0.36))
        return path
    }
}
