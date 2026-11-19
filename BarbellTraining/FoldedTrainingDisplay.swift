import SwiftUI
import AVFoundation

struct FoldedTrainingDisplay: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let reps: Int
    @Binding var note: String
    let remainingSeconds: Int?
    let totalDuration: Int
    let isPaused: Bool
    let showEntireScene: Bool
    let sceneVisible: Bool
    let hudVisible: Bool

    private let imageRatio: CGFloat = 1491.0 / 1055.0

    private var isResting: Bool {
        (remainingSeconds ?? 0) > 0
    }

    private var scene: FoldedScene { Self.scene(for: note) }

    static func backgroundImageName(note: String, isResting: Bool) -> String {
        isResting ? "FoldedRestBurnoutSoft" : scene(for: note).imageName
    }

    private static func scene(for note: String) -> FoldedScene {
        switch note.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "深蹲": return .squat
        case "卧推": return .benchPress
        case "推举", "推肩": return .shoulderPress
        case "划船": return .row
        default: return .deadlift
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let viewport = geometry.size
            let width = showEntireScene ? min(viewport.width, viewport.height * imageRatio) : max(viewport.width, viewport.height * imageRatio) * scene.zoom
            let height = width / imageRatio
            let xOffset = (viewport.width - width) / 2
            let targetY = viewport.height * scene.visibleBarPosition
            let yOffset = showEntireScene ? (viewport.height - height) / 2 : min(0, max(viewport.height - height, targetY - height * scene.barY))
            ZStack(alignment: .topLeading) {
                if isResting {
                    ZStack {
                        Image("FoldedRestBurnoutSoft").resizable().aspectRatio(contentMode: showEntireScene ? .fit : .fill)
                        TrainingLoopVideo(name: "rest", aspectFit: showEntireScene)
                    }
                    .frame(width: viewport.width, height: viewport.height)
                    .clipped()
                    .opacity(sceneVisible ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: sceneVisible)
                } else {
                    ZStack {
                        Image(scene.imageName).resizable()
                        TrainingLoopVideo(name: scene.videoName, aspectFit: showEntireScene)
                        plateOverlay(size: CGSize(width: width, height: height))
                    }
                    .frame(width: width, height: height)
                    .offset(x: xOffset, y: yOffset)
                    .opacity(sceneVisible ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: sceneVisible)
                }

                FoldedTrainingHUD(note: $note, reps: reps, totalWeight: store.total, barWeight: store.barWeight,
                                  todayCount: todayCount, remainingSeconds: remainingSeconds,
                                  totalDuration: totalDuration, isPaused: isPaused, informationY: scene.cardY)
                    .frame(width: viewport.width, height: viewport.height)
                    .opacity(hudVisible ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: hudVisible)
                if store.celebrationID != nil {
                    TrainingVictoryOverlay()
                        .frame(width: viewport.width, height: viewport.height)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(10)
                }
                if !isResting {
                Text(plateDescription)
                    .opacity(hudVisible ? 1 : 0)
                    .font(.custom("ZCOOLQingKeHuangYou-Regular", size: max(9, viewport.width * 0.016)))
                    .foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.7)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.black.opacity(0.75), in: Capsule())
                    .frame(maxWidth: viewport.width * 0.8)
                    .position(x: viewport.width * 0.5, y: viewport.height * 0.96)
                }
            }
            .frame(width: viewport.width, height: viewport.height, alignment: .topLeading)
            .clipped()
        }
    }

    private var todayCount: Int {
        store.sets.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    private var displayedPlates: [Plate] {
        var result: [Plate] = []
        for plate in store.plates.sorted(by: { $0.kilograms > $1.kilograms }) {
            let count = max(0, store.selected[plate.id, default: 0])
            result.append(contentsOf: repeatElement(plate, count: min(count, max(0, 10 - result.count))))
            if result.count == 10 { break }
        }
        return result
    }

    private func plateOverlay(size: CGSize) -> some View {
        ZStack {
            ForEach(Array(displayedPlates.enumerated()), id: \.offset) { index, plate in
                let spacing = min(size.width * 0.018, size.width * scene.stackWidth / CGFloat(max(displayedPlates.count, 1)))
                let plateHeight = size.height * (0.20 + min(plate.kilograms / 25, 1) * 0.14) * scene.plateScale
                let imageWidth = plateHeight * 1024 / 1536
                ForEach([-1, 1], id: \.self) { side in
                    let direction = CGFloat(side)
                    let hubX = size.width * (side < 0 ? scene.leftHub : 1 - scene.leftHub) + direction * CGFloat(index) * spacing
                    RealisticPlateView(color: Color(hex: plate.colorHex), showFace: index == 0)
                        .frame(width: imageWidth, height: plateHeight)
                        .overlay {
                            if index == 0 {
                                // Extend the inner bar from the plate's hole toward the center;
                                // the mirrored plate automatically reverses this direction.
                                Rectangle()
                                    .fill(LinearGradient(colors: [.black, .gray, .white, .gray, .black], startPoint: .top, endPoint: .bottom))
                                    .frame(width: imageWidth * 0.46, height: plateHeight * 0.045)
                                    .position(x: imageWidth * 0.80, y: plateHeight * 0.5)
                            }
                        }
                        .scaleEffect(x: side < 0 ? 1 : -1, y: 1)
                        .position(x: hubX - direction * (-imageWidth * 0.077), y: size.height * scene.barY)
                        .zIndex(-Double(index))
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plateDescription)
    }

    private var plateDescription: String {
        let items = store.plates.sorted { $0.kilograms > $1.kilograms }.compactMap { plate -> String? in
            let count = store.selected[plate.id, default: 0]
            return count > 0 ? "\(plate.label) \(count) 对" : nil
        }
        return items.isEmpty ? "当前空杆" : "当前装片：" + items.joined(separator: "，")
    }
}


private enum FoldedScene {
    case deadlift, squat, benchPress, shoulderPress, row

    var zoom: CGFloat {
        switch self {
        case .shoulderPress: return 1.3
        default: return 1
        }
    }

    var imageName: String {
        switch self {
        case .deadlift: return "FoldedTrainingScene"
        case .squat: return "FoldedSquatScene"
        case .benchPress: return "FoldedBenchScene"
        case .shoulderPress: return "FoldedShoulderPressScene"
        case .row: return "FoldedRowScene"
        }
    }

    var videoName: String {
        switch self {
        case .deadlift: return "deadlift"
        case .squat: return "squat"
        case .benchPress: return "bench"
        case .shoulderPress: return "press"
        case .row: return "row"
        }
    }

    var leftHub: CGFloat {
        switch self {
        case .deadlift: return 0.175
        case .squat: return 0.18
        case .benchPress: return 0.14
        case .shoulderPress: return 0.30
        case .row: return 0.18
        }
    }

    var plateScale: CGFloat {
        switch self {
        case .shoulderPress: return 0.65
        default: return 1
        }
    }

    var stackWidth: CGFloat {
        switch self {
        case .shoulderPress: return 0.085
        default: return 0.12
        }
    }

    var visibleBarPosition: CGFloat {
        switch self {
        case .deadlift: return 0.68
        case .squat, .benchPress, .shoulderPress: return 0.38
        case .row: return 0.48
        }
    }

    var cardY: CGFloat {
        switch self {
        case .deadlift: return 0.22
        case .squat, .benchPress, .shoulderPress, .row: return 0.75
        }
    }

    var modesAtTop: Bool {
        switch self {
        case .deadlift, .row: return true
        case .squat, .benchPress, .shoulderPress: return false
        }
    }

    var barY: CGFloat {
        switch self {
        case .deadlift: return 0.733
        case .squat: return 0.355
        case .benchPress: return 0.235
        case .shoulderPress: return 0.327
        case .row: return 0.438
        }
    }
}

private struct TrainingVictoryOverlay: View {
    @State private var appeared = false
    @State private var alternateVideo = Bool.random()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VictoryVideoView(alternate: alternateVideo)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                Color.black.opacity(0.25)
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Color.purple.opacity(0.8), Color.cyan.opacity(0.65), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: geometry.size.height * 0.26)
                    .rotationEffect(.degrees(-8))
                    .scaleEffect(x: appeared ? 1.5 : 0.1, y: 1)
                VStack(spacing: 0) {
                    Text("YOU WIN")
                        .font(.custom("Orbitron-Regular", size: min(geometry.size.width * 0.14, geometry.size.height * 0.30)).weight(.black))
                        .italic()
                        .foregroundStyle(LinearGradient(colors: [.white, .cyan, Color(red: 0.56, green: 0.35, blue: 1)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .purple, radius: 3, x: 3, y: 3)
                        .shadow(color: .cyan.opacity(0.9), radius: 12)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Text("训练目标达成")
                        .font(.custom("ZCOOLQingKeHuangYou-Regular", size: max(14, geometry.size.height * 0.07)))
                        .foregroundStyle(.white)
                        .shadow(color: .purple, radius: 5)
                }
                .scaleEffect(appeared ? 1 : 1.7)
                .opacity(appeared ? 1 : 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityLabel("胜利，训练目标达成")
        .onAppear { withAnimation(.easeOut(duration: 0.35)) { appeared = true } }
    }
}

private struct VictoryVideoView: UIViewRepresentable {
    let alternate: Bool

    func makeUIView(context: Context) -> VictoryPlayerView {
        let view = VictoryPlayerView()
        let name = alternate ? "TrainingVictoryAlternate" : "TrainingVictory"
        let ext = alternate ? "mp4" : "mov"
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            let player = AVPlayer(url: url)
            view.setPlayer(player)
            player.play()
        }
        return view
    }

    func updateUIView(_ view: VictoryPlayerView, context: Context) {}

    static func dismantleUIView(_ view: VictoryPlayerView, coordinator: ()) {
        view.setPlayer(nil)
    }
}

private final class VictoryPlayerView: UIView {
    private let backgroundPlayerLayer = AVPlayerLayer()
    private let foregroundPlayerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        backgroundPlayerLayer.videoGravity = .resizeAspectFill
        backgroundPlayerLayer.opacity = 0.5
        foregroundPlayerLayer.videoGravity = .resizeAspect
        foregroundPlayerLayer.isOpaque = false
        foregroundPlayerLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(backgroundPlayerLayer)
        layer.addSublayer(foregroundPlayerLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundPlayerLayer.frame = bounds
        foregroundPlayerLayer.frame = bounds
    }

    func setPlayer(_ player: AVPlayer?) {
        if player == nil { foregroundPlayerLayer.player?.pause() }
        backgroundPlayerLayer.player = player
        foregroundPlayerLayer.player = player
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }
}

struct TrainingLoopVideo: UIViewRepresentable {
    let name: String
    var fileExtension = "mp4"
    var isVisible = true
    var aspectFit = false
    @Environment(\.scenePhase) private var scenePhase

    func makeUIView(context: Context) -> TrainingLoopPlayerView {
        let view = TrainingLoopPlayerView()
        view.configure(name: name, fileExtension: fileExtension)
        view.setAspectFit(aspectFit)
        view.setPlaying(scenePhase == .active && isVisible)
        return view
    }

    func updateUIView(_ view: TrainingLoopPlayerView, context: Context) {
        view.configure(name: name, fileExtension: fileExtension)
        view.setAspectFit(aspectFit)
        view.setPlaying(scenePhase == .active && isVisible)
    }

    static func dismantleUIView(_ view: TrainingLoopPlayerView, coordinator: ()) {
        view.stop()
    }
}

final class TrainingLoopPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentName: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    func configure(name: String, fileExtension: String) {
        let resource = "\(name).\(fileExtension)"
        guard currentName != resource else { return }
        stop()
        currentName = resource
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "TrainingVideos") else { return }
        let queue = AVQueuePlayer()
        queue.isMuted = true
        player = queue
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        playerLayer.player = queue
    }

    func setAspectFit(_ enabled: Bool) {
        playerLayer.videoGravity = enabled ? .resizeAspect : .resizeAspectFill
    }

    func setPlaying(_ playing: Bool) {
        if playing { player?.play() } else { player?.pause() }
    }

    func stop() {
        player?.pause()
        looper?.disableLooping()
        looper = nil
        playerLayer.player = nil
        player = nil
        currentName = nil
    }
}
