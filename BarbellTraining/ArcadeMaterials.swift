import SwiftUI

struct PlateEmblem: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle().fill(Color.black).frame(width: 39, height: 39).shadow(color: .black.opacity(0.8), radius: 3, y: 3)
            Circle().fill(LinearGradient(colors: [color.opacity(0.7), color, color.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 36, height: 36)
            Circle().stroke(Color.white.opacity(0.45), lineWidth: 1).frame(width: 33, height: 33)
            Circle().stroke(Color.black.opacity(0.38), lineWidth: 1.5).frame(width: 28, height: 28)
            Circle().stroke(Color.white.opacity(0.16), lineWidth: 1).frame(width: 23, height: 23)
            Circle().fill(LinearGradient(colors: [Color(white: 0.6), Color(white: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 9, height: 9)
            Circle().fill(Color.black).frame(width: 5, height: 5)
            Ellipse().fill(Color.white.opacity(0.22)).frame(width: 18, height: 3).offset(x: -3, y: -12).rotationEffect(.degrees(-20))
        }
        .accessibilityHidden(true)
    }
}

struct ArcadeControlStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let isIncrease: Bool

    func makeBody(configuration: Configuration) -> some View {
        let color = isIncrease ? Color(red: 0.91, green: 0.08, blue: 0.12) : Color(red: 0.08, green: 0.72, blue: 0.16)
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.45))
            .offset(y: pressed ? 1.5 : 0)
            .background {
                ZStack {
                    Image("ArcadeRoundMaterial").resizable().scaledToFit()
                    Circle().fill(color.opacity(0.88)).padding(8).blendMode(.multiply)
                }
                .compositingGroup()
                .shadow(color: color.opacity(pressed && isEnabled ? 0.95 : 0), radius: pressed ? 9 : 0)
                .shadow(color: .black.opacity(0.8), radius: pressed ? 1 : 3, y: pressed ? 1 : 3)
                .offset(y: pressed ? 1.5 : 0)
            }
            .opacity(isEnabled ? 1 : 0.5)
    }
}

struct ControllerButtonStyle: ButtonStyle {
    let color: Color
    var wide = false
    var minHeight: CGFloat = 44
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 15))
            .lineLimit(1).minimumScaleFactor(0.65)
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.45))
            .padding(.horizontal, wide ? 10 : 16)
            .frame(maxWidth: wide ? .infinity : nil, minHeight: minHeight)
        return glassBackground(label, pressed: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.5)
    }

    @ViewBuilder
    private func glassBackground<Content: View>(_ content: Content, pressed: Bool) -> some View {
        if #available(iOS 26.0, *) {
            glassDecoration(content.glassEffect(.clear.tint(color.opacity(pressed ? 0.16 : 0.04)).interactive(), in: .capsule), pressed: pressed)
        } else {
            glassDecoration(content.background(.ultraThinMaterial, in: Capsule()), pressed: pressed)
        }
    }

    private func glassDecoration<Content: View>(_ content: Content, pressed: Bool) -> some View {
        content
            .overlay {
                Capsule().fill(LinearGradient(colors: [.white.opacity(pressed ? 0.05 : 0.02), .clear, color.opacity(pressed ? 0.05 : 0.01)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .allowsHitTesting(false)
            }
            .overlay {
                Capsule().stroke(LinearGradient(colors: [color.opacity(pressed ? 0.8 : 0.35), .white.opacity(pressed ? 0.7 : 0.3), color.opacity(pressed ? 0.8 : 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: pressed ? 2 : 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: color.opacity(pressed && isEnabled ? 0.85 : 0.18), radius: pressed ? 9 : 3)
    }

}

struct ConsoleHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 15))
            .lineLimit(1).minimumScaleFactor(0.65)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(
                LinearGradient(
                    colors: configuration.isPressed
                        ? [Color(red: 0.40, green: 0.17, blue: 0.46), Color(red: 0.16, green: 0.06, blue: 0.22)]
                        : [Color(red: 0.24, green: 0.13, blue: 0.29), Color(red: 0.08, green: 0.05, blue: 0.12)],
                    startPoint: .top, endPoint: .bottom
                ), in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.72, green: 0.28, blue: 0.88), lineWidth: 1))
            .shadow(color: .purple.opacity(configuration.isPressed ? 0.7 : 0.35), radius: configuration.isPressed ? 6 : 3)
    }
}

struct RealisticPlateView: View {
    let color: Color
    let showFace: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                plateImage
                    .overlay {
                        color.opacity(0.85).blendMode(.color)
                    }
                    .compositingGroup()
                    .brightness(0.16)
                    .mask(plateImage)
                if showFace {
                    plateImage
                        .mask {
                            Ellipse()
                                .frame(width: width * 0.055, height: height * 0.20)
                                .position(x: width * 0.577, y: height * 0.50)
                        }
                }
            }
            .mask(alignment: .leading) {
                Rectangle().frame(width: showFace ? width : width * 0.54)
            }
        }
        .accessibilityHidden(true)
    }

    private var plateImage: some View {
        Image("RealisticPlate").resizable()
    }
}


