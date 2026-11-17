import Foundation
import ActivityKit

let trainingAppGroup = "group.com.personal.barbelltraining"
let trainingWidgetKind = "TrainingStatusWidget"

struct TrainingWidgetSnapshot: Codable {
    var date: Date
    var todayCount: Int
    var todayVolume: Double
    var weekDays: Int
    var planCount: Int?
    var planTarget: Int?
    var lastTrainingDate: Date?
    var hasRecordToday: Bool?
    var planStartedAt: Date?
    var recordSet: WidgetTrainingSet?
    var recordSets: [WidgetTrainingSet]?
}

struct WidgetTrainingSet: Codable {
    var action: String
    var weight: Double
    var reps: Int
}

struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var deadline: Date?
        var pausedSeconds: Int?
        var action: String
        var weight: Double
        var reps: Int
    }
    var startedAt: Date
}
