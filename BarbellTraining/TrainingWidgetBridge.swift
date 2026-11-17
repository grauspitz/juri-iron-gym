import Foundation
import WidgetKit
import ActivityKit
import UserNotifications

@MainActor final class TrainingWidgetBridge {
    static let shared = TrainingWidgetBridge()
    private let defaults = UserDefaults(suiteName: trainingAppGroup)
    private let restKey = "restActivityState"
    private var syncTask: Task<Void, Never>?

    func publish(store: TrainingStore) {
        let calendar = Calendar.current
        let today = store.sets.filter { calendar.isDateInToday($0.date) }
        let brokenRecords = store.recordsBroken(on: Date())
        let recordSets = brokenRecords.map { record in
            WidgetTrainingSet(action: record.action, weight: record.current.weight, reps: record.current.reps)
        }
        let interval = calendar.dateInterval(of: .weekOfYear, for: Date())
        let week = store.sets.filter { set in interval.map { $0.contains(set.date) } ?? false }
        let snapshot = TrainingWidgetSnapshot(date: Date(), todayCount: today.count,
            todayVolume: today.reduce(0) { $0 + $1.weight * Double($1.reps) },
            weekDays: Set(week.map { calendar.startOfDay(for: $0.date) }).count,
            planCount: store.activePlan == nil ? nil : store.planProgressCount,
            planTarget: store.activePlan?.target,
            lastTrainingDate: store.sets.filter { $0.date <= Date() }.map(\.date).max(),
            hasRecordToday: !brokenRecords.isEmpty,
            planStartedAt: store.activePlan?.startedAt,
            recordSet: recordSets.last,
            recordSets: recordSets)
        if let data = try? JSONEncoder().encode(snapshot) { defaults?.set(data, forKey: "trainingWidgetSnapshot") }
        WidgetCenter.shared.reloadTimelines(ofKind: trainingWidgetKind)
    }

    func restoredRest() -> RestActivityAttributes.ContentState? {
        guard let data = defaults?.data(forKey: restKey), let state = try? JSONDecoder().decode(RestActivityAttributes.ContentState.self, from: data) else { return nil }
        if state.pausedSeconds == nil && (state.deadline ?? .distantPast) <= Date() { return nil }
        return state
    }

    func syncRest(deadline: Date?, paused: Int?, action: String, weight: Double, reps: Int) {
        let state = RestActivityAttributes.ContentState(deadline: deadline, pausedSeconds: paused, action: action, weight: weight, reps: reps)
        if deadline != nil || paused != nil {
            if let data = try? JSONEncoder().encode(state) { defaults?.set(data, forKey: restKey) }
        } else { defaults?.removeObject(forKey: restKey) }
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            let active = paused != nil || (deadline.map { $0 > Date() } ?? false)
            if #available(iOS 17.0, *) {
                let activities = Activity<RestActivityAttributes>.activities
                if active {
                    let content = ActivityContent(state: state, staleDate: deadline)
                    if let activity = activities.first {
                        await activity.update(content)
                        for extra in activities.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
                    } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                        _ = try? Activity.request(attributes: RestActivityAttributes(startedAt: Date()), content: content, pushType: nil)
                    }
                } else {
                    for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
                }
            }
            await scheduleReminder(deadline: active && paused == nil ? deadline : nil)
        }
    }

    private func scheduleReminder(deadline: Date?) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["trainingRestFinished"])
        guard let deadline = deadline, deadline > Date() else { return }
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = "准备好下一组训练。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "trainingRestFinished", content: content, trigger: trigger))
    }
}
