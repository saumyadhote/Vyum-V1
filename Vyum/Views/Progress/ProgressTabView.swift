import SwiftUI

/// Weekly stats, and the latest posture analysis.
struct ProgressTabView: View {
    @Binding var selectedTab: AppTab
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = ProgressViewModel()
    @State private var isShowingSettings = false

    var body: some View {
        @Bindable var viewModel = viewModel
        let dashboard = viewModel.dashboard(history: appModel.history)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Picker("Section", selection: $viewModel.section) {
                        ForEach(ProgressSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("progress.period")

                    if let error = appModel.historyError {
                        NoteBox(title: "Progress unavailable", message: error, systemImage: "exclamationmark.triangle")
                    }

                    switch viewModel.section {
                    case .weekly:
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            PeriodHeader(dashboard: dashboard)
                            StreakCard(dashboard: dashboard)
                            StatsGrid(dashboard: dashboard)
                        }
                    case .postureAnalysis:
                        PostureAnalysisView(analysis: viewModel.latestPostureAnalysis())
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.xl)
            }
            .vyumScreenBackground()
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.section)
    }
}

// MARK: - Sections

/// This week at a glance: the current streak and which days had a session.
private struct StreakCard: View {
    let dashboard: ProgressDashboard

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(dashboard.currentStreak > 0 ? Color.orange : Color.vyumTextSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(streakTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.vyumTextPrimary)
                    Text(streakSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.vyumTextSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 0) {
                ForEach(dashboard.weekDays) { day in
                    DayDot(day: day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.vyumSurface, in: .rect(cornerRadius: Radius.plate, style: .continuous))
    }

    private var streakTitle: String {
        switch dashboard.currentStreak {
        case 0: "Start a streak today"
        case 1: "1-day streak"
        default: "\(dashboard.currentStreak)-day streak"
        }
    }

    private var streakSubtitle: String {
        let longest = dashboard.longestStreak
        if dashboard.currentStreak > 0 && dashboard.currentStreak >= longest { return "Your longest yet. Keep it going!" }
        return longest == 0 ? "A few minutes counts." : "Longest: \(longest) \(longest == 1 ? "day" : "days")"
    }
}

private struct DayDot: View {
    let day: ProgressDashboard.WeekDay

    var body: some View {
        VStack(spacing: 6) {
            Text(day.date, format: .dateTime.weekday(.narrow))
                .font(.caption.weight(.semibold))
                .foregroundStyle(day.isToday ? Color.vyumTextPrimary : Color.vyumTextSecondary)
            ZStack {
                Circle()
                    .fill(day.isActive ? Color.vyumAccentFill : Color.vyumSurfaceEmphasis)
                    .opacity(day.isFuture ? 0.4 : 1)
                if day.isToday && !day.isActive {
                    Circle().strokeBorder(Color.vyumAccentFill, lineWidth: 2)
                }
                if day.isActive {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.vyumOnAccent)
                }
            }
            .frame(width: 34, height: 34)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let status = day.isActive ? "Active" : (day.isFuture ? "Upcoming" : "No session")
        return day.isToday ? "Today, \(status)" : status
    }
}

private struct PeriodHeader: View {
    let dashboard: ProgressDashboard

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(dashboard.period == .week ? "This week" : "This month")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(rangeText)
                .font(.subheadline)
                .foregroundStyle(Color.vyumTextSecondary)
        }
    }

    private var rangeText: String {
        switch dashboard.period {
        case .week:
            // The interval's end is the start of the next week; show the last day.
            let lastDay = dashboard.interval.end.addingTimeInterval(-1)
            return "\(dashboard.interval.start.formatted(.dateTime.day().month())) – \(lastDay.formatted(.dateTime.day().month()))"
        case .month:
            return dashboard.interval.start.formatted(.dateTime.month(.wide).year())
        }
    }
}

private struct StatsGrid: View {
    let dashboard: ProgressDashboard

    var body: some View {
        Grid(horizontalSpacing: Spacing.sm, verticalSpacing: Spacing.sm) {
            GridRow {
                StatTile(
                    value: "\(dashboard.exercisesDone)",
                    label: dashboard.exercisesDone == 1 ? "Exercise done" : "Exercises done",
                    systemImage: "figure.cooldown"
                )
                StatTile(
                    value: "\(dashboard.activeDays)",
                    suffix: "of \(dashboard.daysInPeriod)",
                    label: "Active days",
                    systemImage: "calendar"
                )
            }
            GridRow {
                StatTile(
                    value: "\(dashboard.postureReports)",
                    label: dashboard.postureReports == 1 ? "Posture report" : "Posture reports",
                    systemImage: "camera.viewfinder"
                )
                StatTile(
                    value: "\(dashboard.minutes)",
                    label: dashboard.minutes == 1 ? "Minute moving" : "Minutes moving",
                    systemImage: "clock"
                )
            }
        }
    }
}

private struct StatTile: View {
    let value: String
    var suffix: String?
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.vyumAccentFill)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(value)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.vyumTextPrimary)
                if let suffix {
                    Text(suffix)
                        .font(.subheadline)
                        .foregroundStyle(Color.vyumTextSecondary)
                }
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.vyumTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.md)
        .background(Color.vyumSurface, in: .rect(cornerRadius: Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(Color.vyumSeparator, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ProgressTabView(selectedTab: .constant(.progress))
        .environment(AppModel.preview())
}
