import Foundation

/// The result of one posture check: how long the person was clearly in view,
/// what was noticed, and what to try.
///
/// PLACEHOLDER: the app doesn't analyse posture yet, so the screen shows `.sample`.
/// A real analyser should produce this same shape.
struct PostureAnalysis: Equatable {
    enum Reliability: Equatable {
        case reliable
        case notAssessed

        var title: String {
            switch self {
            case .reliable: "Reliable"
            case .notAssessed: "Not assessed"
            }
        }
    }

    /// How a finding compares with the previous check.
    enum Trend: Equatable {
        case better(String)
        case unchanged(String)
        case worse(String)
    }

    struct Finding: Identifiable, Equatable {
        let title: String
        let detail: String
        let trend: Trend?
        let reliability: Reliability
        var id: String { title }
    }

    struct Tip: Identifiable, Equatable {
        let text: String
        let systemImage: String
        var id: String { text }
    }

    let checkedAt: Date
    /// Length of the check.
    let duration: TimeInterval
    /// Time the person was clearly in view; only this counts towards the findings.
    let observedDuration: TimeInterval
    let comparedWithPrevious: Bool
    let findings: [Finding]
    let tips: [Tip]

    var observedFraction: Double {
        duration > 0 ? min(observedDuration / duration, 1) : 0
    }

    /// "Good" once most of the check was usable.
    var observationQuality: String {
        switch observedFraction {
        case 0.8...: "Good"
        case 0.5..<0.8: "Fair"
        default: "Low"
        }
    }
}

extension PostureAnalysis {
    static func sample(now: Date, calendar: Calendar = .current) -> PostureAnalysis {
        let checkedAt = calendar.date(bySettingHour: 10, minute: 42, second: 0, of: now) ?? now
        return PostureAnalysis(
            checkedAt: min(checkedAt, now),
            duration: 10 * 60,
            observedDuration: 8 * 60 + 40,
            comparedWithPrevious: true,
            findings: [
                Finding(title: "Head forward", detail: "Forward for about 42% of this check", trend: .better("13 percentage points since last check"), reliability: .reliable),
                Finding(title: "Shoulders", detail: "Mostly level · slight right lean", trend: .unchanged("Unchanged since your last check"), reliability: .reliable),
                Finding(title: "Lower back", detail: "Not enough visible to assess", trend: nil, reliability: .notAssessed),
            ],
            tips: [
                Tip(text: "Raise your screen closer to eye level", systemImage: "lightbulb"),
                Tip(text: "Stand and stretch every 30 minutes", systemImage: "figure.stand"),
            ]
        )
    }
}
