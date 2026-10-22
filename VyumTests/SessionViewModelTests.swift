import Foundation
import Testing
@testable import Vyum

@MainActor
struct SessionViewModelTests {
    let clock = TestClock()

    private func makeSession(_ plan: SessionPlan = Fixtures.threeExercisePlan) -> SessionViewModel {
        SessionViewModel(plan: plan, clock: clock.function)
    }

    @Test("starts in get-ready for the first exercise")
    func initialState() {
        let session = makeSession()
        #expect(session.index == 0)
        #expect(session.stage == .getReady)
        #expect(session.status == .running)
        #expect(session.remainingSeconds == Int(SessionPlan.getReadySeconds))
    }

    @Test("moves from get-ready to active when the countdown ends")
    func getReadyToActive() {
        let session = makeSession()
        clock.advance(SessionPlan.getReadySeconds)
        session.tick()
        #expect(session.stage == .active)
        #expect(session.remainingSeconds == 30)
    }

    @Test("completing an exercise counts it and moves to the next")
    func completesExercise() {
        let session = makeSession()
        session.startNow()
        clock.advance(30)
        session.tick()
        #expect(session.completedCount == 1)
        #expect(session.index == 1)
        #expect(session.stage == .getReady)
    }

    @Test("pausing freezes the timer; resuming continues from the same point")
    func pauseAndResume() {
        let session = makeSession()
        session.startNow()
        clock.advance(10)
        session.pause()
        clock.advance(120)
        session.tick()
        #expect(session.isPaused)
        #expect(session.remainingSeconds == 20)

        session.resume()
        clock.advance(5)
        session.tick()
        #expect(session.remainingSeconds == 15)
        #expect(session.stage == .active)
    }

    @Test("skip moves on without counting the exercise as done")
    func skipDoesNotCount() {
        let session = makeSession()
        session.startNow()
        clock.advance(5)
        session.skip()
        #expect(session.index == 1)
        #expect(session.completedCount == 0)
        #expect(session.activeSeconds == 5)
    }

    @Test("back during an exercise restarts it; back during get-ready goes to the previous one")
    func goBack() {
        let session = makeSession()
        session.skip()
        #expect(session.index == 1)

        session.startNow()
        session.goBack()
        #expect(session.index == 1)
        #expect(session.stage == .getReady)

        session.goBack()
        #expect(session.index == 0)
        #expect(session.canGoBack == false)
    }

    @Test("finishing every exercise completes the session and produces a record")
    func completesSession() throws {
        let session = makeSession()
        for exercise in session.plan.exercises {
            session.startNow()
            clock.advance(exercise.duration)
            session.tick()
        }
        #expect(session.status == .finished(completedAll: true))
        let result = try #require(session.result)
        #expect(result.exercisesCompleted == 3)
        #expect(result.exercisesTotal == 3)
        #expect(result.activeSeconds == 60)
        #expect(result.finishedAll)
    }

    @Test("ending early keeps the work done so far")
    func endEarly() throws {
        let session = makeSession()
        session.startNow()
        clock.advance(30)
        session.tick()
        session.startNow()
        clock.advance(8)
        session.end()

        #expect(session.status == .finished(completedAll: false))
        let result = try #require(session.result)
        #expect(result.exercisesCompleted == 1)
        #expect(result.activeSeconds == 38)
    }

    @Test("very short sessions are not recorded")
    func shortSessionNotRecorded() {
        let session = makeSession()
        session.startNow()
        clock.advance(5)
        session.end()
        #expect(session.isFinished)
        #expect(session.result == nil)
    }

    @Test("controls do nothing after the session has finished")
    func controlsIgnoredWhenFinished() {
        let session = makeSession()
        session.end()
        session.resume()
        session.skip()
        session.goBack()
        #expect(session.isFinished)
        #expect(session.snapshot() == nil)
    }

    @Test("two-sided exercises report the switch at the halfway point")
    func secondSide() {
        let plan = Fixtures.plan([Fixtures.exercise("hip", duration: 60, bothSides: true)])
        let session = makeSession(plan)
        session.startNow()
        clock.advance(29)
        session.tick()
        #expect(session.isOnSecondSide == false)
        clock.advance(1)
        session.tick()
        #expect(session.isOnSecondSide)
    }

    @Test("a snapshot restores the same position, paused")
    func snapshotRoundTrip() throws {
        let session = makeSession()
        session.startNow()
        clock.advance(30)
        session.tick()
        session.startNow()
        clock.advance(12)
        session.tick()

        let snapshot = try #require(session.snapshot())
        let restored = SessionViewModel(snapshot: snapshot, clock: clock.function)

        #expect(restored.index == 1)
        #expect(restored.stage == .active)
        #expect(restored.isPaused)
        #expect(restored.completedCount == 1)
        #expect(restored.remainingSeconds == 8)
        #expect(restored.activeSeconds == session.activeSeconds)
    }

    @Test("cue key changes on each meaningful transition")
    func cueKeyChanges() {
        let session = makeSession()
        let first = session.cueKey
        session.startNow()
        let second = session.cueKey
        session.skip()
        #expect(first != second)
        #expect(second != session.cueKey)
    }
}
