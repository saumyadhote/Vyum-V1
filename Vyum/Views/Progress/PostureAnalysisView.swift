import SwiftUI

/// The latest posture check: observation quality, findings and suggestions.
struct PostureAnalysisView: View {
    let analysis: PostureAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(heading)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.vyumTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(subheading)
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
            }

            ObservationCard(analysis: analysis)
            FindingsCard(findings: analysis.findings)
            TipsCard(tips: analysis.tips)

            Text("Preview · posture analysis isn't live yet, so these results are examples.")
                .font(.footnote)
                .foregroundStyle(Color.vyumTextSecondary)
        }
    }

    private var heading: String {
        let time = analysis.checkedAt.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(analysis.checkedAt) { return "Today, \(time)" }
        return "\(analysis.checkedAt.formatted(.dateTime.day().month())), \(time)"
    }

    private var subheading: String {
        let minutes = Int((analysis.duration / 60).rounded())
        return analysis.comparedWithPrevious
            ? "\(minutes) min check · compared with your last check"
            : "\(minutes) min check"
    }
}

// MARK: - Cards

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.vyumSurface, in: .rect(cornerRadius: Radius.plate, style: .continuous))
    }
}

/// Small outlined capsule, e.g. "Good" or "Reliable".
private struct StatusBadge: View {
    let text: String
    var prominent = true

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(prominent ? Color.vyumAccentFill : Color.vyumTextSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 4)
            .overlay(Capsule().strokeBorder(prominent ? Color.vyumAccentFill : Color.vyumTextSecondary, lineWidth: 1))
            .fixedSize()
    }
}

private struct ObservationCard: View {
    let analysis: PostureAnalysis

    var body: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Valid observation time")
                    .font(.headline)
                    .foregroundStyle(Color.vyumTextPrimary)
                Spacer()
                StatusBadge(text: analysis.observationQuality, prominent: analysis.observedFraction >= 0.8)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ProgressView(value: analysis.observedFraction)
                    .tint(Color.vyumAccentFill)
                    .accessibilityHidden(true)
                Text("\(clock(analysis.observedDuration)) of \(clock(analysis.duration)) clearly in view")
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct FindingsCard: View {
    let findings: [PostureAnalysis.Finding]

    var body: some View {
        Card {
            Text("What we noticed")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(findings) { finding in
                FindingRow(finding: finding)
            }
        }
    }
}

private struct FindingRow: View {
    let finding: PostureAnalysis.Finding

    private var assessed: Bool { finding.reliability == .reliable }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                    .font(.headline)
                    .foregroundStyle(assessed ? Color.vyumTextPrimary : Color.vyumTextSecondary)
                Text(finding.detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
                if let trend = finding.trend {
                    trendText(trend)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            StatusBadge(text: finding.reliability.title, prominent: assessed)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func trendText(_ trend: PostureAnalysis.Trend) -> some View {
        switch trend {
        case .better(let text):
            Label(text, systemImage: "arrow.down")
                .labelStyle(TrendLabelStyle())
                .foregroundStyle(.green)
        case .worse(let text):
            Label(text, systemImage: "arrow.up")
                .labelStyle(TrendLabelStyle())
                .foregroundStyle(.orange)
        case .unchanged(let text):
            Text(text)
                .foregroundStyle(Color.vyumTextSecondary)
        }
    }
}

/// Icon and text on one baseline, sized with the text.
private struct TrendLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

private struct TipsCard: View {
    let tips: [PostureAnalysis.Tip]

    var body: some View {
        Card {
            Text("Try this")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(tips) { tip in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: tip.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.vyumAccentFill)
                        .frame(width: 40, height: 40)
                        .background(Color.vyumAccentSoft, in: .rect(cornerRadius: Radius.control, style: .continuous))
                        .accessibilityHidden(true)
                    Text(tip.text)
                        .font(.body)
                        .foregroundStyle(Color.vyumTextPrimary)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        PostureAnalysisView(analysis: .sample(now: .now))
            .padding()
    }
    .vyumScreenBackground()
}
