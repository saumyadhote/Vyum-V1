import Foundation
import Testing
@testable import Vyum

struct ProgressDashboardTests {
    /// Gregorian, Monday-first, UTC, so weeks and months are predictable.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func session(on day: Date, exercises: Int, minutes: Double = 5) -> CompletedSession {
        CompletedSession(
            id: UUID(), routineID: nil, title: "Session",
            startedAt: day.addingTimeInterval(-minutes * 60), endedAt: day,
            activeSeconds: minutes * 60, exercisesCompleted: exercises, exercisesTotal: exercises
        )
    }

    // Wednesday 14 October 2026. Its week runs Mon 12 – Sun 18.
    private var now: Date { date(2026, 10, 14, hour: 18) }

    @Test("weekly totals count only this week's sessions")
    func weeklyTotals() {
        let history = [
            session(on: date(2026, 10, 12), exercises: 7, minutes: 7),
            session(on: date(2026, 10, 12, hour: 15), exercises: 4, minutes: 3),
            session(on: date(2026, 10, 14), exercises: 3, minutes: 2),
            session(on: date(2026, 10, 9), exercises: 9),   // last week
        ]
        let dashboard = ProgressDashboard(history: history, postureReportDates: [], period: .week, now: now, calendar: calendar)

        #expect(dashboard.exercisesDone == 14)
        #expect(dashboard.activeDays == 2, "Two sessions on the same day count once")
        #expect(dashboard.daysInPeriod == 7)
        #expect(dashboard.minutes == 12)
        #expect(dashboard.bars.count == 7)
        #expect(dashboard.bars.map(\.exercises) == [11, 0, 3, 0, 0, 0, 0])
    }

    @Test("monthly view covers the whole month, in weekly bars")
    func monthlyTotals() {
        let history = [
            session(on: date(2026, 10, 1), exercises: 5),
            session(on: date(2026, 10, 14), exercises: 7),
            session(on: date(2026, 9, 30), exercises: 9),   // last month
        ]
        let dashboard = ProgressDashboard(history: history, postureReportDates: [], period: .month, now: now, calendar: calendar)

        #expect(dashboard.exercisesDone == 12)
        #expect(dashboard.activeDays == 2)
        #expect(dashboard.daysInPeriod == 31)
        // October 2026 spans five Monday-first weeks: 1–4, 5–11, 12–18, 19–25, 26–31.
        #expect(dashboard.bars.count == 5)
        #expect(dashboard.bars.map(\.exercises) == [5, 0, 7, 0, 0])
        #expect(dashboard.bars.reduce(0) { $0 + $1.exercises } == dashboard.exercisesDone)
    }

    @Test("posture reports are counted for the period, with the latest date")
    func postureReports() {
        let reports = [date(2026, 10, 13), date(2026, 10, 2), date(2026, 9, 20)]
        let week = ProgressDashboard(history: [], postureReportDates: reports, period: .week, now: now, calendar: calendar)
        let month = ProgressDashboard(history: [], postureReportDates: reports, period: .month, now: now, calendar: calendar)

        #expect(week.postureReports == 1)
        #expect(month.postureReports == 2)
        #expect(month.latestPostureReport == date(2026, 10, 13))
    }

    @Test("all sessions are listed newest first, whatever the period")
    func allSessions() {
        let older = session(on: date(2026, 8, 1), exercises: 3)
        let newer = session(on: date(2026, 10, 13), exercises: 3)
        let dashboard = ProgressDashboard(history: [older, newer], postureReportDates: [], period: .week, now: now, calendar: calendar)
        #expect(dashboard.allSessions.map(\.id) == [newer.id, older.id])
    }

    @Test("streak counts consecutive days ending today, and survives until a full day is missed")
    func streaks() {
        let days = [14, 13, 12, 9, 8, 7, 6].map { date(2026, 10, $0) }
        let history = days.map { session(on: $0, exercises: 3) }
        let dashboard = ProgressDashboard(history: history, postureReportDates: [], period: .week, now: now, calendar: calendar)
        #expect(dashboard.currentStreak == 3)
        #expect(dashboard.longestStreak == 4)

        // No session yet today: yesterday's run still counts.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let next = ProgressDashboard(history: history, postureReportDates: [], period: .week, now: tomorrow, calendar: calendar)
        #expect(next.currentStreak == 3)
    }

    @Test("week strip marks active, today and future days")
    func weekStrip() {
        let history = [session(on: date(2026, 10, 12), exercises: 3), session(on: date(2026, 10, 14), exercises: 3)]
        let dashboard = ProgressDashboard(history: history, postureReportDates: [], period: .week, now: now, calendar: calendar)
        #expect(dashboard.weekDays.count == 7)
        #expect(dashboard.weekDays.map(\.isActive) == [true, false, true, false, false, false, false])
        #expect(dashboard.weekDays.firstIndex(where: \.isToday) == 2)
        #expect(dashboard.weekDays.filter(\.isFuture).count == 4)
    }

    @Test("sample data gives a four-day streak")
    func sampleStreak() {
        #expect(ProgressDashboard.sample(period: .week, now: now, calendar: calendar).currentStreak == 4)
    }

    @Test("no history gives an empty dashboard")
    func empty() {
        let dashboard = ProgressDashboard(history: [], postureReportDates: [], period: .week, now: now, calendar: calendar)
        #expect(dashboard.exercisesDone == 0)
        #expect(dashboard.activeDays == 0)
        #expect(dashboard.latestPostureReport == nil)
        #expect(dashboard.allSessions.isEmpty)
    }

    @Test("sample data fills every section and never lies in the future")
    func sample() {
        for period in ProgressPeriod.allCases {
            let dashboard = ProgressDashboard.sample(period: period, now: now, calendar: calendar)
            #expect(dashboard.exercisesDone > 0)
            #expect(dashboard.activeDays > 0)
            #expect(dashboard.postureReports > 0)
            #expect(!dashboard.allSessions.isEmpty)
            #expect(dashboard.allSessions.allSatisfy { $0.endedAt <= now })
        }
    }
}

@MainActor
struct ProgressViewModelTests {
    @Test("starts on the weekly section")
    func startsWeekly() {
        #expect(ProgressViewModel().section == .weekly)
        #expect(ProgressViewModel().dashboard(history: []).period == .week)
    }

    @Test("switching period changes the dashboard")
    func switchesPeriod() {
        let viewModel = ProgressViewModel(usesSampleData: true)
        #expect(viewModel.dashboard(history: []).period == .week)
        viewModel.period = .month
        #expect(viewModel.dashboard(history: []).period == .month)
    }

    @Test("with sample data off, the dashboard uses real history")
    func realData() {
        let viewModel = ProgressViewModel(usesSampleData: false)
        let dashboard = viewModel.dashboard(history: [])
        #expect(dashboard.exercisesDone == 0)
        #expect(dashboard.postureReports == 0)
    }
}

struct PostureAnalysisTests {
    private func analysis(observed: TimeInterval, of total: TimeInterval) -> PostureAnalysis {
        PostureAnalysis(checkedAt: .now, duration: total, observedDuration: observed, comparedWithPrevious: false, findings: [], tips: [])
    }

    @Test("observation quality follows how much of the check was usable")
    func quality() {
        #expect(analysis(observed: 520, of: 600).observationQuality == "Good")
        #expect(analysis(observed: 360, of: 600).observationQuality == "Fair")
        #expect(analysis(observed: 120, of: 600).observationQuality == "Low")
    }

    @Test("observed fraction is clamped and safe for a zero-length check")
    func fraction() {
        #expect(analysis(observed: 700, of: 600).observedFraction == 1)
        #expect(analysis(observed: 10, of: 0).observedFraction == 0)
    }

    @Test("the sample matches the design: 8:40 of 10:00, three findings, two tips")
    func sample() {
        let s = PostureAnalysis.sample(now: .now)
        #expect(s.observedDuration == 520 && s.duration == 600)
        #expect(s.findings.map(\.title) == ["Head forward", "Shoulders", "Lower back"])
        #expect(s.findings.last?.reliability == .notAssessed)
        #expect(s.tips.count == 2)
        #expect(s.checkedAt <= .now)
    }
}
