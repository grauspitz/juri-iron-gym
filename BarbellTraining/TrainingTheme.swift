import SwiftUI
import UIKit

enum TrainingTheme {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.42, blue: 0.68, alpha: 1)
            : UIColor(red: 0.66, green: 0.10, blue: 0.36, alpha: 1)
    })
    static let teal = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.40, green: 0.88, blue: 0.87, alpha: 1)
            : UIColor(red: 0.04, green: 0.43, blue: 0.45, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.10, alpha: 0.81)
            : UIColor(white: 1, alpha: 0.81)
    })
}

struct CyberGymTitle: View {
    var title = "蛛莉铁馆"

    var body: some View {
        HStack(spacing: 7) {
            Rectangle().fill(TrainingTheme.teal).frame(width: 3, height: 23)
                .rotationEffect(.degrees(12))
            ZStack {
                Text(title).foregroundStyle(TrainingTheme.accent.opacity(0.65)).offset(x: 1.5, y: 1)
                Text(title).foregroundStyle(TrainingTheme.teal.opacity(0.65)).offset(x: -1.5, y: -1)
                Text(title).foregroundStyle(.primary)
            }
            .font(.custom("ZCOOLQingKeHuangYou-Regular", size: 29))
            .italic()
            .shadow(color: TrainingTheme.teal.opacity(0.45), radius: 4)
            Rectangle().fill(TrainingTheme.accent).frame(width: 8, height: 3)
                .offset(y: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

struct TrainingBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isFolded(geometry) {
                    let backgroundName = geometry.size.width > geometry.size.height ? "TrainingBackgroundFoldedLandscape" : "TrainingBackgroundBattle"
                    Image(backgroundName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 24)
                        .clipped()
                    Image(backgroundName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if horizontalSizeClass == .compact && geometry.size.width > geometry.size.height {
                    Image("TrainingBackgroundOuterLandscape")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 24)
                        .clipped()
                    Image("TrainingBackgroundOuterLandscape")
                        .resizable()
                        .scaledToFit()
                        .mask {
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white, location: 0.08),
                                .init(color: .white, location: 0.92),
                                .init(color: .clear, location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if horizontalSizeClass == .regular && geometry.size.height >= geometry.size.width {
                    Image("TrainingBackgroundInnerPortrait")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 24)
                        .clipped()
                    Image("TrainingBackgroundInnerPortrait")
                        .resizable()
                        .scaledToFit()
                        .mask {
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white, location: 0.08),
                                .init(color: .white, location: 0.92),
                                .init(color: .clear, location: 1)
                            ], startPoint: .leading, endPoint: .trailing)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if horizontalSizeClass == .regular && geometry.size.width > geometry.size.height {
                    Image("TrainingBackgroundInnerLandscape")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else if geometry.size.width >= 780 || geometry.size.width > geometry.size.height {
                    Image("TrainingBackgroundWide")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 24)
                        .clipped()
                    Image("TrainingBackgroundWide")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    Image(horizontalSizeClass == .compact ? "TrainingBackgroundOuterPortrait" : "TrainingBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .overlay(colorScheme == .dark ? Color.black.opacity(0.58) : Color.white.opacity(0.68))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func isFolded(_ geometry: GeometryProxy) -> Bool {
        if #available(iOS 27.1, *) {
            return !geometry.reservedRegions(kind: .division).isEmpty
        }
        return false
    }
}

struct TrainingActionStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.handheldControls) private var handheldControls
    @Environment(\.trainingModeUI) private var trainingModeUI
    @Environment(\.trainingLandscape) private var trainingLandscape

    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if trainingModeUI && !handheldControls {
            configuration.label
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(red: 0.15, green: 0.03, blue: 0.12))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(LinearGradient(colors: [Color(red: 1, green: 0.70, blue: 0.84), Color(red: 0.95, green: 0.34, blue: 0.62)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.30, green: 0.03, blue: 0.22), lineWidth: 2))
                .shadow(color: .black.opacity(0.5), radius: 1, y: configuration.isPressed ? 1 : 3)
                .offset(y: configuration.isPressed ? 2 : 0)
                .opacity(isEnabled ? 1 : 0.5)
        } else if handheldControls && !trainingLandscape {
            configuration.label
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .background {
                    Capsule().fill(Color(red: 0.48, green: 0.02, blue: 0.04))
                        .offset(y: 3).shadow(color: .black.opacity(0.55), radius: 2, y: 3)
                    Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.32, blue: 0.34), Color(red: 0.87, green: 0.035, blue: 0.08), Color(red: 0.67, green: 0.02, blue: 0.05)], startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().stroke(Color.black.opacity(0.45), lineWidth: 1))
                        .overlay(Capsule().inset(by: 2).stroke(Color.white.opacity(0.22), lineWidth: 1))
                }
                .offset(y: configuration.isPressed ? 2 : 0)
                .opacity(isEnabled ? 1 : 0.5)
        } else if handheldControls {
            PlasticButtonStyle(color: Color(red: 1, green: 0.66, blue: 0.76), padded: true)
                .makeBody(configuration: configuration)
                .font(.subheadline.weight(.semibold))
        } else {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(kind == .primary ? (colorScheme == .dark ? Color.black : Color.white) : TrainingTheme.accent)
            .background(kind == .primary ? TrainingTheme.accent : TrainingTheme.accent.opacity(0.10), in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .contentShape(Capsule())
        }
    }
}

struct TrainingTagStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? TrainingTheme.accent : Color.primary)
            .background(selected ? TrainingTheme.accent.opacity(0.14) : Color.primary.opacity(0.06), in: Capsule())
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct TrainingRowLabel: View {
    let title: String
    let systemImage: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(TrainingTheme.teal)
                .frame(width: 22)
            Text(title).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct TrainingRecordSelectionStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(TrainingTheme.teal.opacity(configuration.isPressed ? 0.28 : (selected ? 0.16 : 0)),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(TrainingTheme.teal.opacity(configuration.isPressed ? 0.75 : (selected ? 0.45 : 0)), lineWidth: 1)
            }
    }
}
