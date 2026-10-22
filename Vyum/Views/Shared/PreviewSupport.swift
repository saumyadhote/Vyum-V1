#if DEBUG
import Foundation

/// In-memory stand-ins so previews never touch real user data.
final class PreviewHistoryStore: SessionHistoryStoring {
    var sessions: [CompletedSession]

    init(sessions: [CompletedSession] = []) {
        self.sessions = sessions
    }

    func fetchAll() throws -> [CompletedSession] { sessions.sorted { $0.endedAt > $1.endedAt } }
    func add(_ session: CompletedSession) throws { sessions.append(session) }
    func deleteAll() throws { sessions.removeAll() }
}

final class PreviewPreferencesStore: PreferencesStoring {
    var preferences: UserPreferences

    init(_ preferences: UserPreferences) {
        self.preferences = preferences
    }

    func load() -> UserPreferences { preferences }
    func save(_ preferences: UserPreferences) { self.preferences = preferences }
}

final class PreviewSnapshotStore: SessionSnapshotStoring {
    var snapshot: SessionSnapshot?

    func load() -> SessionSnapshot? { snapshot }
    func save(_ snapshot: SessionSnapshot) { self.snapshot = snapshot }
    func clear() { snapshot = nil }
}

struct PreviewReminderService: ReminderScheduling {
    func requestAuthorization() async -> Bool { true }
    func scheduleDailyReminder(at time: ReminderTime) async throws {}
    func cancelReminders() {}
}

extension AppModel {
    static func preview(onboarded: Bool = true, withHistory: Bool = true) -> AppModel {
        var preferences = UserPreferences()
        preferences.hasCompletedOnboarding = onboarded
        preferences.focusAreas = [.neck, .upperBack]

        let now = Date()
        let sessions: [CompletedSession] = withHistory ? [1, 2, 4].map { daysAgo in
            let end = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return CompletedSession(
                id: UUID(),
                routineID: "desk-reset",
                title: "Desk Reset",
                startedAt: end.addingTimeInterval(-200),
                endedAt: end,
                activeSeconds: 175,
                exercisesCompleted: daysAgo == 4 ? 2 : 4,
                exercisesTotal: 4
            )
        } : []

        let model = AppModel(
            libraryService: BundledExerciseLibraryService(),
            preferencesStore: PreviewPreferencesStore(preferences),
            historyStore: PreviewHistoryStore(sessions: sessions),
            snapshotStore: PreviewSnapshotStore(),
            reminders: PreviewReminderService()
        )
        model.load()
        return model
    }
}

extension SessionViewModel {
    static func preview() -> SessionViewModel {
        let model = AppModel.preview()
        let library = model.library
        let routine = library?.routine(id: "desk-reset")
        let plan = routine.flatMap(model.plan(for:)) ?? SessionPlan(routineID: nil, title: "Preview", exercises: [])
        return SessionViewModel(plan: plan)
    }
}
#endif
