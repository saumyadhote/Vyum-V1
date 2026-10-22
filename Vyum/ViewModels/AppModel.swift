import Foundation
import Observation

/// App-wide state shared by every tab: content, preferences, history and the
/// session currently on screen.
@MainActor @Observable
final class AppModel {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var loadState: LoadState = .loading
    private(set) var library: ExerciseLibrary?
    private(set) var preferences: UserPreferences
    private(set) var history: [CompletedSession] = []
    private(set) var historyError: String?
    /// An interrupted session that can be resumed from Today.
    private(set) var resumableSnapshot: SessionSnapshot?
    /// The session shown full screen, if any.
    var activeSession: SessionViewModel?
    /// The session that just ended; Today shows a short confirmation for it.
    private(set) var lastFinishedSession: CompletedSession?

    private let libraryService: ExerciseLibraryProviding
    private let preferencesStore: PreferencesStoring
    private let historyStore: SessionHistoryStoring?
    private let snapshotStore: SessionSnapshotStoring
    let reminders: ReminderScheduling
    private let clock: () -> Date

    init(
        libraryService: ExerciseLibraryProviding,
        preferencesStore: PreferencesStoring,
        historyStore: SessionHistoryStoring?,
        snapshotStore: SessionSnapshotStoring,
        reminders: ReminderScheduling,
        clock: @escaping () -> Date = Date.init
    ) {
        self.libraryService = libraryService
        self.preferencesStore = preferencesStore
        self.historyStore = historyStore
        self.snapshotStore = snapshotStore
        self.reminders = reminders
        self.clock = clock
        preferences = preferencesStore.load()
    }

    // MARK: - Loading

    func load() {
        loadState = .loading
        do {
            library = try libraryService.loadLibrary()
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
        reloadHistory()
        if let snapshot = snapshotStore.load(), snapshot.isResumable(at: clock()) {
            resumableSnapshot = snapshot
        } else {
            snapshotStore.clear()
        }
    }

    func reloadHistory() {
        guard let historyStore else {
            historyError = "Your progress can't be saved on this device right now."
            return
        }
        do {
            history = try historyStore.fetchAll()
            historyError = nil
        } catch {
            historyError = "Your progress couldn't be loaded."
        }
    }

    // MARK: - Derived

    var todaysRoutine: Routine? {
        guard let library else { return nil }
        return RoutineRecommender(library: library).recommendation(for: preferences, on: clock())
    }

    var quickPicks: [Routine] {
        guard let library else { return [] }
        let todayID = todaysRoutine?.id
        return RoutineRecommender(library: library)
            .rankedRoutines(for: preferences)
            .filter { $0.id != todayID }
    }

    var progress: ProgressSummary {
        ProgressSummary(history: history, now: clock())
    }

    func plan(for routine: Routine) -> SessionPlan? {
        library.map { SessionPlan(routine: routine, library: $0) }
    }

    // MARK: - Preferences

    func updatePreferences(_ update: (inout UserPreferences) -> Void) {
        update(&preferences)
        preferencesStore.save(preferences)
    }

    func completeOnboarding(with draft: UserPreferences) {
        var finished = draft
        finished.hasCompletedOnboarding = true
        preferences = finished
        preferencesStore.save(finished)
    }

    // MARK: - Sessions

    func start(_ plan: SessionPlan) {
        guard !plan.exercises.isEmpty else { return }
        discardResumableSession()
        lastFinishedSession = nil
        activeSession = SessionViewModel(plan: plan, clock: clock)
    }

    func resumeInterruptedSession() {
        guard let snapshot = resumableSnapshot else { return }
        resumableSnapshot = nil
        activeSession = SessionViewModel(snapshot: snapshot, clock: clock)
    }

    func discardResumableSession() {
        resumableSnapshot = nil
        snapshotStore.clear()
    }

    /// Saves where the person is so the session survives the app closing.
    func saveProgress(of session: SessionViewModel) {
        if let snapshot = session.snapshot() {
            snapshotStore.save(snapshot)
        }
    }

    /// Called when the session screen goes away, finished or not.
    func sessionDismissed(_ session: SessionViewModel) {
        defer { activeSession = nil }
        guard session.isFinished else {
            // Closed without ending (should not normally happen): keep it resumable.
            saveProgress(of: session)
            resumableSnapshot = session.snapshot()
            return
        }
        snapshotStore.clear()
        guard let result = session.result else { return }
        lastFinishedSession = result
        do {
            try historyStore?.add(result)
            reloadHistory()
        } catch {
            reloadHistory()
            historyError = "This session couldn't be saved."
        }
    }

    func dismissFinishedConfirmation() {
        lastFinishedSession = nil
    }

    func resetProgress() {
        discardResumableSession()
        do {
            try historyStore?.deleteAll()
            reloadHistory()
        } catch {
            reloadHistory()
            historyError = "Your progress couldn't be reset. Please try again."
        }
    }
}
