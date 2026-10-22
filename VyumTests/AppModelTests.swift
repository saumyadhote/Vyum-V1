import Foundation
import Testing
@testable import Vyum

@MainActor
struct AppModelTests {
    let clock = TestClock()
    let history = InMemoryHistoryStore()
    let preferences = InMemoryPreferencesStore()
    let snapshots = InMemorySnapshotStore()
    let reminders = MockReminders()

    private func makeModel(
        library: ExerciseLibraryProviding = BundledExerciseLibraryService(),
        historyStore: SessionHistoryStoring? = nil
    ) -> AppModel {
        let model = AppModel(
            libraryService: library,
            preferencesStore: preferences,
            historyStore: historyStore ?? history,
            snapshotStore: snapshots,
            reminders: reminders,
            clock: clock.function
        )
        model.load()
        return model
    }

    @Test("loads bundled content and suggests a routine")
    func loadsLibrary() {
        let model = makeModel()
        #expect(model.loadState == .loaded)
        #expect(model.library?.exercises.count == 14)
        #expect(model.todaysRoutine != nil)
    }

    @Test("Week 1 has all seven exercises, in order")
    func weekOneProgramme() throws {
        let model = makeModel()
        let library = try #require(model.library)
        let weekOne = try #require(library.routine(id: Routine.weekOneID))
        #expect(library.exercises(in: weekOne).map(\.id) == [
            "shoulder-rolls", "neck-rotations", "side-neck-stretch", "back-neck-stretch",
            "chin-tuck", "scapular-squeeze", "doorway-chest-stretch",
        ])
    }

    @Test("shows an error state when content can't be loaded")
    func libraryFailure() {
        let model = makeModel(library: FailingLibraryService())
        guard case .failed = model.loadState else {
            Issue.record("Expected failed state, got \(model.loadState)")
            return
        }
        #expect(model.todaysRoutine == nil)
    }

    @Test("completing onboarding persists preferences")
    func onboarding() {
        let model = makeModel()
        var draft = UserPreferences()
        draft.focusAreas = [.hips]
        model.completeOnboarding(with: draft)

        #expect(model.preferences.hasCompletedOnboarding)
        #expect(preferences.stored.hasCompletedOnboarding)
        #expect(preferences.stored.focusAreas == [.hips])
    }

    @Test("a finished session is saved to history and confirmed on Today")
    func finishedSessionSaved() throws {
        let model = makeModel()
        let plan = Fixtures.threeExercisePlan
        model.start(plan)
        let session = try #require(model.activeSession)
        session.startNow()
        clock.advance(30)
        session.tick()
        session.end()

        model.sessionDismissed(session)

        #expect(model.activeSession == nil)
        #expect(model.history.count == 1)
        #expect(model.lastFinishedSession?.exercisesCompleted == 1)
        #expect(snapshots.snapshot == nil)
        #expect(model.progress.totalSessions == 1)
    }

    @Test("a save failure is reported rather than silently lost")
    func saveFailure() throws {
        history.failNextAdd = true
        let model = makeModel()
        model.start(Fixtures.threeExercisePlan)
        let session = try #require(model.activeSession)
        session.startNow()
        clock.advance(30)
        session.end()
        model.sessionDismissed(session)

        #expect(model.historyError != nil)
        #expect(model.history.isEmpty)
    }

    @Test("an interrupted session is offered for resuming after relaunch")
    func resumeAfterRelaunch() throws {
        let first = makeModel()
        first.start(Fixtures.threeExercisePlan)
        let session = try #require(first.activeSession)
        session.startNow()
        clock.advance(10)
        session.pause()
        first.saveProgress(of: session)

        let relaunched = makeModel()
        let snapshot = try #require(relaunched.resumableSnapshot)
        #expect(snapshot.index == 0)

        relaunched.resumeInterruptedSession()
        let resumed = try #require(relaunched.activeSession)
        #expect(resumed.isPaused)
        #expect(resumed.remainingSeconds == 20)
        #expect(relaunched.resumableSnapshot == nil)
    }

    @Test("old interrupted sessions are discarded on launch")
    func staleSnapshotDiscarded() throws {
        let first = makeModel()
        first.start(Fixtures.threeExercisePlan)
        let session = try #require(first.activeSession)
        first.saveProgress(of: session)

        clock.advance(SessionSnapshot.maximumAge + 1)
        let relaunched = makeModel()

        #expect(relaunched.resumableSnapshot == nil)
        #expect(snapshots.snapshot == nil)
    }

    @Test("starting a new session discards any interrupted one")
    func startDiscardsSnapshot() throws {
        let model = makeModel()
        model.start(Fixtures.threeExercisePlan)
        let session = try #require(model.activeSession)
        model.saveProgress(of: session)
        model.start(Fixtures.threeExercisePlan)
        #expect(snapshots.snapshot == nil)
    }

    @Test("an empty plan does not open the player")
    func emptyPlanIgnored() {
        let model = makeModel()
        model.start(Fixtures.plan([]))
        #expect(model.activeSession == nil)
    }

    @Test("reset removes history")
    func resetProgress() throws {
        history.sessions = [CompletedSession(
            id: UUID(), routineID: nil, title: "T",
            startedAt: clock.now, endedAt: clock.now,
            activeSeconds: 60, exercisesCompleted: 1, exercisesTotal: 1
        )]
        let model = makeModel()
        #expect(model.history.count == 1)
        model.resetProgress()
        #expect(model.history.isEmpty)
    }
}
