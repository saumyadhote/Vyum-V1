import Foundation
import Observation

/// The two views on the Progress screen.
enum ProgressSection: String, CaseIterable, Identifiable, Sendable {
    case weekly
    case postureAnalysis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .postureAnalysis: "Posture Analysis"
        }
    }
}

/// State for the Progress screen: which section is shown, and where its numbers come from.
@MainActor @Observable
final class ProgressViewModel {
    var section: ProgressSection = .weekly
    /// The stats period. The screen only shows the week now; month is kept for the dashboard model.
    var period: ProgressPeriod = .week

    /// MOCK: true for now, so Weekly shows example stats and a streak. Set false to build
    /// the dashboard from real session history.
    let usesSampleData: Bool

    private let now: () -> Date

    init(usesSampleData: Bool = true, now: @escaping () -> Date = Date.init) {
        self.usesSampleData = usesSampleData
        self.now = now
    }

    func dashboard(history: [CompletedSession]) -> ProgressDashboard {
        if usesSampleData {
            return .sample(period: period, now: now())
        }
        return ProgressDashboard(history: history, postureReportDates: [], period: period, now: now())
    }

    /// The latest posture check. Sample content until posture analysis exists.
    func latestPostureAnalysis() -> PostureAnalysis {
        .sample(now: now())
    }
}
