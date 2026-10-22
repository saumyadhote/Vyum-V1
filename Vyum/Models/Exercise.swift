import Foundation

nonisolated enum BodyArea: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case neck
    case shoulders
    case upperBack
    case back
    case hips
    case legs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neck: "Neck"
        case .shoulders: "Shoulders"
        case .upperBack: "Upper back"
        case .back: "Back"
        case .hips: "Hips"
        case .legs: "Legs"
        }
    }

    var systemImage: String {
        switch self {
        case .neck: "person.bust"
        case .shoulders: "figure.arms.open"
        case .upperBack: "figure.stand"
        case .back: "figure.flexibility"
        case .hips: "figure.cooldown"
        case .legs: "figure.walk"
        }
    }
}

nonisolated enum ExercisePosition: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case seated
    case standing
    case floor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seated: "Seated"
        case .standing: "Standing"
        case .floor: "On the floor"
        }
    }

    var systemImage: String {
        switch self {
        case .seated: "chair"
        case .standing: "figure.stand"
        case .floor: "figure.yoga"
        }
    }
}

nonisolated enum Equipment: String, Codable, Hashable, Sendable {
    case none
    case chair
    case wall
    case doorway

    /// Short label for what the person needs, or nil when nothing is required.
    var title: String? {
        switch self {
        case .none: nil
        case .chair: "Chair"
        case .wall: "Wall"
        case .doorway: "Doorway"
        }
    }
}

nonisolated struct Exercise: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let summary: String
    let bodyAreas: [BodyArea]
    let position: ExercisePosition
    let equipment: Equipment
    let durationSeconds: Int
    let repsGuide: String
    let bothSides: Bool
    /// Asset name, or nil while the artwork hasn't been drawn yet.
    let illustration: String?
    let illustrationDescription: String
    let steps: [String]
    let easier: [String]
    let cautions: [String]
    /// How to set up before starting.
    var startingPosition: String? = nil
    /// Hold or pacing guidance, when it isn't covered by the steps.
    var hold: String? = nil
    /// What the person should expect to feel.
    var feel: String? = nil
    /// How to do the second side, for exercises done on each side.
    var switchSides: String? = nil

    var duration: TimeInterval { TimeInterval(durationSeconds) }
}

nonisolated struct Routine: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let exerciseIDs: [String]
    /// A short note shown before the routine starts.
    var intro: String? = nil

    /// The starter programme, featured on Home and at the top of Exercises.
    static let weekOneID = "week-1"
}

/// Bundled exercise content. Decoded once at launch.
nonisolated struct ExerciseLibrary: Codable, Sendable {
    let contentStatus: String
    let exercises: [Exercise]
    let routines: [Routine]

    func exercise(id: String) -> Exercise? {
        exercises.first { $0.id == id }
    }

    func exercises(in routine: Routine) -> [Exercise] {
        routine.exerciseIDs.compactMap(exercise(id:))
    }

    func routine(id: String) -> Routine? {
        routines.first { $0.id == id }
    }
}
