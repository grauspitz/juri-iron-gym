import SwiftUI

struct TrainingBootScreen: View {
    let started: Date
    let duration: TimeInterval
    let isShutdown: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(started))
            let progress = min(1, elapsed / duration)
            let full = duration > 2
            let ready = full ? elapsed >= 3.8 : progress >= 0.78
            let showLogo = isShutdown ? elapsed < 1.15 : (full ? elapsed >= 1.2 : elapsed >= 0.2)
            let loading = full ? min(1, max(0, (elapsed - 2) / 1.8)) : min(1, max(0, (progress - 0.25) / 0.53))
            let eased = 1 - pow(1 - loading, 2)
            let color: Color = ready ? Color(red: 0.68, green: 1, blue: 0.12) : .purple

            GeometryReader { geometry in
                ZStack {
                    Color.black
                    if !isShutdown && elapsed >= (full ? 0.5 : 0) && !showLogo {
                        Circle().stroke(Color.purple.opacity(0.7), lineWidth: 2)
                            .frame(width: min(geometry.size.width, geometry.size.height) * min(0.7, 0.1 + progress))
                            .shadow(color: .purple, radius: 16)
                        Circle().fill(Color.white).frame(width: 6, height: 6).shadow(color: .purple, radius: 16)
                    }
                    if isShutdown && elapsed >= 1.1 {
                        Capsule().fill(LinearGradient(colors: [.clear, .purple, .white, .purple, .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geometry.size.width * max(0, 1 - (elapsed - 1.1) / 0.6), height: 3)
                            .shadow(color: .purple, radius: 12)
                    }
                    if showLogo {
                        VStack(spacing: max(3, min(10, geometry.size.height * 0.025))) {
                            Image("TrainingStartupArtwork")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: geometry.size.width * 0.96, maxHeight: geometry.size.height * 0.78)
                                .accessibilityLabel("蛛俐铁馆训练系统")
                            if !isShutdown && (full ? elapsed >= 2 : progress >= 0.25) {
                                progressBar(progress: eased, ready: ready, color: color)
                                    .frame(width: min(geometry.size.width * 0.7, 460))
                                HStack {
                                    Text(ready ? "READY" : loading < 0.35 ? "LOADING PROFILE" : loading < 0.7 ? "CALIBRATING EQUIPMENT" : "PREPARING TRAINING")
                                    Spacer()
                                    Text("\(Int(eased * 100))%")
                                }
                                .font(.custom("Orbitron-Regular", size: max(7, min(10, geometry.size.height * 0.03))))
                                .foregroundStyle(color)
                                .frame(width: min(geometry.size.width * 0.7, 460))
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isShutdown ? "正在退出训练模式" : "正在启动训练模式")
    }

    private func progressBar(progress: Double, ready: Bool, color: Color) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.purple.opacity(0.2))
                RoundedRectangle(cornerRadius: 3).fill(color)
                    .frame(width: geometry.size.width * progress)
                    .shadow(color: color.opacity(0.8), radius: ready ? 7 : 4)
                HStack(spacing: 0) {
                    ForEach(0..<16, id: \.self) { _ in
                        Spacer(minLength: 0)
                        Rectangle().fill(Color.black.opacity(0.55)).frame(width: 2)
                    }
                }
            }
        }
        .frame(height: 7)
    }
}

struct TrainingShutdownScreen: View {
    let started: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(started))
            let fadeIn = min(1, elapsed / 0.6)
            let energy = max(0.2, 1 - max(0, elapsed - 1.1) / 1.3 * 0.8)
            let compression = max(0.005, 1 - max(0, elapsed - 2.4) / 0.22)
            let lineWidth = max(0, 1 - max(0, elapsed - 2.62) / 0.28)
            let remaining = max(0, min(1, 1 - (elapsed - 1.1) / 1.3))
            GeometryReader { geometry in
                ZStack {
                    Color.black.opacity(fadeIn)
                    if elapsed >= 0.35 && elapsed < 2.9 {
                        Circle()
                            .stroke(Color.purple.opacity(0.13 * energy), lineWidth: 1)
                            .frame(width: min(geometry.size.width, geometry.size.height) * 0.55)
                            .scaleEffect(1 + min(0.2, elapsed * 0.06))
                        VStack(spacing: max(3, min(10, geometry.size.height * 0.025))) {
                            TrainingEmblem()
                                .frame(width: min(117, geometry.size.height * 0.34), height: min(99, geometry.size.height * 0.29))
                                .shadow(color: .purple.opacity(0.8 * energy), radius: 18)
                            CyberGymTitle(title: "蛛俐铁馆")
                                .scaleEffect(min(1, max(0.55, geometry.size.height / 250)))
                            Text("SYSTEM SHUTTING DOWN")
                                .tracking(2)
                                .font(.custom("Orbitron-Regular", size: max(8, min(11, geometry.size.height * 0.035))))
                                .foregroundStyle(Color.purple.opacity(energy))
                            shutdownBar(remaining: remaining)
                                .frame(width: min(geometry.size.width * 0.55, 340), height: 5)
                            Text("POWERING OFF TRAINING SYSTEM")
                                .tracking(0.8)
                                .font(.custom("Orbitron-Regular", size: 7))
                                .foregroundStyle(Color.purple.opacity(0.65 * energy))
                        }
                        .opacity(fadeIn * energy)
                        .scaleEffect(x: elapsed < 2.62 ? 1 : lineWidth, y: compression)
                        if elapsed >= 2.4 {
                            Capsule()
                                .fill(LinearGradient(colors: [.clear, .purple, .white, .purple, .clear], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geometry.size.width * 0.72 * lineWidth, height: 2)
                                .shadow(color: .purple, radius: 12)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在退出训练模式")
    }

    private func shutdownBar(remaining: Double) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    Capsule().fill(Double(index) / 12 < remaining ? Color.purple : Color.purple.opacity(0.15))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

private struct TrainingEmblem: View {
    var body: some View {
        ZStack {
            EmblemShield()
                .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.07, blue: 0.30), Color(red: 0.05, green: 0.02, blue: 0.12)], startPoint: .top, endPoint: .bottom))
            EmblemShield()
                .stroke(LinearGradient(colors: [.white.opacity(0.9), .pink, .purple, .cyan.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
                .shadow(color: .purple.opacity(0.75), radius: 7)
            EmblemFace()
                .stroke(LinearGradient(colors: [.pink, Color(red: 0.8, green: 0.5, blue: 1), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .shadow(color: .pink, radius: 5)
                .offset(y: 5)
        }
        .accessibilityHidden(true)
    }
}

private struct EmblemShield: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: point(0.08, 0.29))
        path.addLine(to: point(0.18, 0.08))
        path.addLine(to: point(0.35, 0.25))
        path.addLine(to: point(0.5, 0.11))
        path.addLine(to: point(0.65, 0.25))
        path.addLine(to: point(0.82, 0.08))
        path.addLine(to: point(0.92, 0.29))
        path.addLine(to: point(0.88, 0.67))
        path.addLine(to: point(0.5, 0.92))
        path.addLine(to: point(0.12, 0.67))
        path.closeSubpath()
        return path
    }
}

private struct EmblemFace: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: point(0.22, 0.4))
        path.addLine(to: point(0.40, 0.49))
        path.addLine(to: point(0.30, 0.57))
        path.move(to: point(0.78, 0.4))
        path.addLine(to: point(0.60, 0.49))
        path.addLine(to: point(0.70, 0.57))
        path.move(to: point(0.32, 0.69))
        path.addLine(to: point(0.5, 0.60))
        path.addLine(to: point(0.68, 0.69))
        return path
    }
}

struct ArcadeSpeakerPanel: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(white: 0.08), Color(white: 0.17), Color(white: 0.06)], startPoint: .leading, endPoint: .trailing)
                VStack(spacing: max(3, geometry.size.width * 0.10)) {
                    ForEach(0..<5, id: \.self) { _ in
                        HStack(spacing: max(3, geometry.size.width * 0.10)) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle().fill(Color.black)
                                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                                    .frame(width: min(5, geometry.size.width * 0.1), height: min(5, geometry.size.width * 0.1))
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .trailing) { Rectangle().fill(Color.purple.opacity(0.4)).frame(width: 1) }
        }
    }
}
