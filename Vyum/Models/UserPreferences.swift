import Foundation

nonisolated enum PositionPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case seatedOnly
    case any

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seatedOnly: "Seated only"
        case .any: "Seated or standing"
        }
    }
}

nonisolated enum SessionLength: String, Codable, CaseIterable, Identifiable, Sendable {
    case short
    case standard
    case long

    var id: String { rawValue }

    var targetMinutes: Int {
        switch self {
        case .short: 3
        case .standard: 5
        case .long: 10
        }
    }

    var title: String { "About \(targetMinutes) min" }
}

nonisolated struct ReminderTime: Codable, Hashable, Sendable {
    var hour: Int
    var minute: Int

    static let defaultTime = ReminderTime(hour: 11, minute: 0)
}

nonisolated struct UserPreferences: Codable, Hashable, Sendable {
    var hasCompletedOnboarding = false
    var focusAreas: Set<BodyArea> = []
    var positionPreference: PositionPreference = .any
    var sessionLength: SessionLength = .standard
    var remindersEnabled = false
    var reminderTime: ReminderTime = .defaultTime
}
