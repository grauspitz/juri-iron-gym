import SwiftUI
import CoreText
import UIKit
import OSLog

@main
struct BarbellTrainingApp: App {
    @UIApplicationDelegateAdaptor(TrainingAppDelegate.self) private var appDelegate
    @StateObject private var store = TrainingStore()

    init() {
        for name in ["Orbitron", "ZCOOLQingKeHuangYou-Regular", "BaoCanMouHuiTing-Regular"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}

enum ShareShortcutLog {
    private static let logger = Logger(subsystem: "com.personal.barbelltraining", category: "ShareShortcut")
    static func write(_ event: String, _ fields: [String: Any] = [:]) {
        var payload = fields
        payload["event"] = event
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return }
        logger.info("\(json, privacy: .public)")
    }
}

@MainActor final class TrainingShortcuts: ObservableObject {
    static let shared = TrainingShortcuts()
    static let shareToday = "com.personal.barbelltraining.shareToday"
    @Published var pendingShare = false
    private var lastURLReceivedAt: TimeInterval = 0

    func receiveURL(_ url: URL, source: String) {
        let matches = url.scheme?.lowercased() == "barbelltraining" && url.host?.lowercased() == "share-today"
        ShareShortcutLog.write("url_received", ["source": source, "scheme": url.scheme ?? "", "host": url.host ?? "", "matches": matches])
        guard matches else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastURLReceivedAt > 1 else {
            ShareShortcutLog.write("url_duplicate_ignored", ["source": source])
            return
        }
        lastURLReceivedAt = now
        pendingShare = true
    }

    func receive(_ item: UIApplicationShortcutItem) -> Bool {
        guard item.type == Self.shareToday else { return false }
        pendingShare = true
        return true
    }
}

final class TrainingAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.shortcutItems = [UIApplicationShortcutItem(type: TrainingShortcuts.shareToday,
            localizedTitle: "分享今日卡片", localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "square.and.arrow.up"), userInfo: nil)]
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = TrainingSceneDelegate.self
        return configuration
    }
}

final class TrainingSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem { _ = TrainingShortcuts.shared.receive(item) }
        for context in connectionOptions.urlContexts {
            TrainingShortcuts.shared.receiveURL(context.url, source: "scene_connect")
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            TrainingShortcuts.shared.receiveURL(context.url, source: "scene_open")
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(TrainingShortcuts.shared.receive(shortcutItem))
    }
}
