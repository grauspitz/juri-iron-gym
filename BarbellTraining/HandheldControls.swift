import SwiftUI
import UIKit

struct ControlContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

extension View {
    func metalPanel() -> some View {
        self.padding(9)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.12, green: 0.09, blue: 0.09))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.65), lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 9).inset(by: 2).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
            }
    }
}

struct LCDDisplay: View {
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 2) {
                ForEach(Array(value.enumerated()), id: \.offset) { _, character in
                    if character == ":" {
                        VStack(spacing: 5) {
                            Circle().frame(width: 3, height: 3)
                            Circle().frame(width: 3, height: 3)
                        }
                    } else {
                        LCDDigit(character: character)
                    }
                }
            }
            .foregroundStyle(Color(red: 0.75, green: 1, blue: 0.22))
            .shadow(color: .green.opacity(0.5), radius: 3)
            Text(unit).font(.custom("Orbitron-Regular", size: 10).weight(.bold))
                .foregroundStyle(Color(red: 0.58, green: 0.72, blue: 0.54))
        }
        .frame(width: 110, height: 40)
        .background {
            Image("ArcadeLCDMaterial").resizable()
                .frame(width: 110, height: 40)
                .scaleEffect(1.12)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.65), radius: 2, y: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(unit)")
    }
}

private struct LCDDigit: View {
    let character: Character
    private let segments: [Character: String] = [
        "0": "abcdef", "1": "bc", "2": "abged",
        "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgecd", "7": "abc",
        "8": "abcdefg", "9": "abfgcd"
    ]

    var body: some View {
        let active = segments[character] ?? ""
        return ZStack {
            segment("a", active: active).frame(width: 9, height: 2).offset(y: -10)
            segment("g", active: active).frame(width: 9, height: 2)
            segment("d", active: active).frame(width: 9, height: 2).offset(y: 10)
            segment("f", active: active).frame(width: 2, height: 8).offset(x: -5, y: -5)
            segment("b", active: active).frame(width: 2, height: 8).offset(x: 5, y: -5)
            segment("e", active: active).frame(width: 2, height: 8).offset(x: -5, y: 5)
            segment("c", active: active).frame(width: 2, height: 8).offset(x: 5, y: 5)
        }
        .frame(width: 12, height: 22)
    }

    private func segment(_ name: Character, active: String) -> some View {
        RoundedRectangle(cornerRadius: 1).opacity(active.contains(name) ? 1 : 0.10)
    }
}

struct FoldHinge: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [.black, Color(white: 0.27), Color(white: 0.10), .black],
                               startPoint: .top, endPoint: .bottom)
                HStack(spacing: 0) {
                    hingeCap
                    hingeBar
                    hingeCap
                }
                .padding(.horizontal, geometry.size.width * 0.04)
                .padding(.vertical, min(geometry.size.height * 0.18, 5))
                Rectangle().fill(Color.white.opacity(0.14))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
                Rectangle().fill(Color.black.opacity(0.8))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .clipped()
        }
        .allowsHitTesting(false)
    }

    private var hingeBar: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(LinearGradient(colors: [Color(white: 0.13), Color(white: 0.39), Color(white: 0.19), Color(white: 0.06)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }

    private var hingeCap: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
            .frame(width: 18)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.8), lineWidth: 1))
    }
}


struct ArcadeAdjustButton: View {
    let symbol: String
    let label: String
    var disabled = false
    var playsSound = true
    var showArithmeticSymbol = false
    let action: () -> Void

    var body: some View {
        if #available(iOS 17.0, *) {
            button.buttonRepeatBehavior(.enabled)
        } else {
            button
        }
    }

    private var button: some View {
        Button {
            if playsSound { TrainingFeedback.adjust() }
            else { TrainingFeedback.adjustHaptic() }
            action()
        } label: {
            Image(systemName: showArithmeticSymbol ? symbol : (symbol == "plus" ? "arrow.up" : "arrow.down"))
                .font(.system(size: 18, weight: .black))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ArcadeControlStyle(isIncrease: symbol == "plus"))
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}

struct ControllerPanelBackground: View {
    var isHandheld = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isHandheld {
                    Color(red: 0.72, green: 0.055, blue: 0.075)
                    Canvas { context, size in
                        for index in 0..<6500 {
                            let seed = UInt64(index) &* 2_654_435_761 &+ 1_013_904_223
                            let mixed = (seed ^ (seed >> 13)) &* 2_246_822_519
                            let x = CGFloat(mixed % 10_007) / 10_007 * size.width
                            let y = CGFloat((mixed >> 16) % 10_009) / 10_009 * size.height
                            let dot = CGRect(x: x, y: y, width: index.isMultiple(of: 5) ? 1.2 : 0.7, height: 0.7)
                            context.fill(Path(ellipseIn: dot), with: .color(index.isMultiple(of: 2) ? .white.opacity(0.09) : .black.opacity(0.12)))
                        }
                    }
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.black.opacity(0.28), lineWidth: 1)
                        .padding(3)
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        .padding(5)
                    VStack {
                        HStack {
                            screw
                            Spacer()
                            screw
                        }
                        Spacer()
                        HStack {
                            screw
                            Spacer()
                            screw
                        }
                    }
                    .padding(10)
                    HStack(alignment: .bottom) {
                        HStack(spacing: 5) {
                            ForEach(0..<4, id: \.self) { _ in
                                Capsule().fill(Color.black.opacity(0.68))
                                    .frame(width: 4, height: 24)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                            }
                        }
                        .rotationEffect(.degrees(42))
                        .padding(.leading, 18)
                        .padding(.bottom, 20)
                        Spacer()
                        VStack(spacing: 0) {
                            Text("SUP").font(.system(size: 25, weight: .black, design: .rounded)).italic()
                            Rectangle().frame(width: 56, height: 4)
                            Rectangle().frame(width: 56, height: 2).padding(.top, 2)
                        }
                        .foregroundStyle(Color(red: 0.91, green: 0.88, blue: 0.83))
                        .rotationEffect(.degrees(-35))
                        .padding(.trailing, 8)
                        .padding(.bottom, 18)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                } else {
                    Image("ArcadePanelMaterial").resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    RoundedRectangle(cornerRadius: 36)
                        .stroke(Color.white.opacity(0.12), lineWidth: 2)
                        .padding(8)
                    Color.black.opacity(0.25)
                }
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private var screw: some View {
        Circle().fill(Color(red: 0.35, green: 0.055, blue: 0.06))
            .overlay(Capsule().fill(Color.black.opacity(0.5)).frame(width: 4, height: 1).rotationEffect(.degrees(-35)))
            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            .frame(width: 7, height: 7)
    }
}


struct HandheldGripShape: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        let corners: UIRectCorner = isLeft ? [.topLeft, .bottomLeft] : [.topRight, .bottomRight]
        return Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: 24, height: 24)).cgPath)
    }
}

struct GripJoystick: View {
    let size: CGFloat
    let color: Color
    let label: String
    let action: () -> Void
    let onDrag: (CGSize) -> Void
    @GestureState private var translation: CGSize = .zero

    init(size: CGFloat, color: Color, label: String, action: @escaping () -> Void, onDrag: @escaping (CGSize) -> Void) {
        self.size = size
        self.color = color
        self.label = label
        self.action = action
        self.onDrag = onDrag
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.black).shadow(color: .black.opacity(0.8), radius: 4, y: 4)
            Circle().stroke(color.opacity(0.85), lineWidth: max(2, size * 0.06)).padding(size * 0.08)
            Circle().fill(LinearGradient(colors: [Color(white: 0.28), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(size * 0.18)
                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1).padding(size * 0.18))
                .offset(x: max(-size * 0.12, min(size * 0.12, translation.width)), y: max(-size * 0.12, min(size * 0.12, translation.height)))
        }
        .frame(width: size, height: size)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .updating($translation) { value, state, _ in state = value.translation }
            .onEnded { value in
                if max(abs(value.translation.width), abs(value.translation.height)) < 12 { action() }
                else { onDrag(value.translation) }
            })
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }
}

struct GripPlasticButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        return configuration.label
            .foregroundStyle(Color(red: 0.23, green: 0.23, blue: 0.22))
            .background {
                shape.fill(Color(red: 0.24, green: 0.24, blue: 0.23))
                    .offset(y: 3)
                    .shadow(color: .black.opacity(0.55), radius: 2, y: 3)
                shape.fill(Color(red: 0.78, green: 0.77, blue: 0.74))
                    .overlay {
                        Canvas { context, size in
                            for index in 0..<500 {
                                let seed = UInt64(index) &* 2_654_435_761 &+ 1_013_904_223
                                let x = CGFloat(seed % 10_007) / 10_007 * size.width
                                let y = CGFloat((seed >> 16) % 10_009) / 10_009 * size.height
                                let grain = CGRect(x: x, y: y, width: 0.6, height: 0.6)
                                context.fill(Path(ellipseIn: grain), with: .color(index.isMultiple(of: 2) ? .white.opacity(0.10) : .black.opacity(0.08)))
                            }
                        }
                        .clipShape(shape)
                        .allowsHitTesting(false)
                    }
                    .overlay(shape.stroke(Color.black.opacity(0.18), lineWidth: 1))
                    .overlay(alignment: .top) {
                        shape.stroke(Color.white.opacity(0.23), lineWidth: 1).padding(1).mask(
                            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)
                        )
                    }
                    .offset(y: configuration.isPressed ? 2 : 0)
            }
            .offset(y: configuration.isPressed ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.6)
    }
}
