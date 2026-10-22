import SwiftUI

/// The daily home: one clear suggestion with a single primary action.
struct TodayView: View {
    @Binding var selectedTab: AppTab
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if let finished = appModel.lastFinishedSession {
                        SavedBanner(session: finished) { appModel.dismissFinishedConfirmation() }
                            .transition(.opacity)
                    }

                    if let snapshot = appModel.resumableSnapshot {
                        ResumeSection(snapshot: snapshot)
                    }

                    if let routine = appModel.todaysRoutine, let plan = appModel.plan(for: routine) {
                        TodaySuggestion(routine: routine, plan: plan) {
                            appModel.start(plan)
                        }
                    }

                    WeekSummaryLine(summary: appModel.progress) {
                        selectedTab = .progress
                    }

                    if !appModel.quickPicks.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            SectionHeader(title: "Other sessions")
                            ForEach(appModel.quickPicks) { routine in
                                if let plan = appModel.plan(for: routine) {
                                    NavigationLink(value: AppRoute.routine(routine.id)) {
                                        RoutineRow(routine: routine, plan: plan)
                                    }
                                    .buttonStyle(.plain)
                                    if routine.id != appModel.quickPicks.last?.id {
                                        BrandDivider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.xl)
                .animation(Motion.standard(reduceMotion: reduceMotion), value: appModel.lastFinishedSession)
            }
            .vyumScreenBackground()
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("today.settings")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .appRouteDestinations()
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

// MARK: - Sections

private struct TodaySuggestion: View {
    let routine: Routine
    let plan: SessionPlan
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Today's suggestion")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.vyumTextSecondary)

            if let first = plan.exercises.first {
                IllustrationPlate(imageName: first.illustration, description: first.illustrationDescription, maxHeight: 220)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(routine.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.vyumTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(routine.summary)
                    .font(.body)
                    .foregroundStyle(Color.vyumTextSecondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.md) { meta }
                    VStack(alignment: .leading, spacing: Spacing.xxs) { meta }
                }
            }

            VStack(spacing: Spacing.sm) {
                Button(action: onStart) {
                    Label("Start session", systemImage: "play.fill")
                }
                .buttonStyle(.vyumPrimary)
                .accessibilityIdentifier("today.start")

                NavigationLink(value: AppRoute.routine(routine.id)) {
                    Text("See what's included")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: TouchTarget.minimum)
                        .contentShape(.rect)
                }
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityIdentifier("today.details")
            }
        }
    }

    @ViewBuilder private var meta: some View {
        MetaLabel(text: "\(plan.roundedMinutes) min", systemImage: "clock")
        MetaLabel(text: "\(plan.exercises.count) exercises", systemImage: "list.bullet")
        MetaLabel(text: positionsText, systemImage: plan.positions == [.seated] ? "chair" : "figure.stand")
    }

    private var positionsText: String {
        let order: [ExercisePosition] = [.seated, .standing, .floor]
        let names = order.filter(plan.positions.contains).map(\.title)
        return names.joined(separator: " & ")
    }
}

private struct ResumeSection: View {
    let snapshot: SessionSnapshot
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.title2)
                    .foregroundStyle(Color.vyumTextPrimary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Pick up where you left off")
                        .font(.headline)
                        .foregroundStyle(Color.vyumTextPrimary)
                    Text("\(snapshot.plan.title) · \(snapshot.completedCount) of \(snapshot.plan.exercises.count) done")
                        .font(.subheadline)
                        .foregroundStyle(Color.vyumTextSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: Spacing.sm) {
                Button("Resume") { appModel.resumeInterruptedSession() }
                    .buttonStyle(.vyumPrimary)
                    .accessibilityIdentifier("today.resume")
                Button("Discard") { appModel.discardResumableSession() }
                    .buttonStyle(.vyumSecondary)
                    .accessibilityHint("Removes the unfinished session")
            }
        }
        .padding(Spacing.md)
        .background(Color.vyumSurface, in: .rect(cornerRadius: Radius.plate, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.plate, style: .continuous)
                .strokeBorder(Color.vyumSeparator, lineWidth: 1)
        )
    }
}

private struct SavedBanner: View {
    let session: CompletedSession
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityHidden(true)
            Text("Saved: \(session.title), \(DurationText.short(session.activeSeconds)) of movement.")
                .font(.subheadline)
                .foregroundStyle(Color.vyumTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.vyumTextSecondary)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, Spacing.md)
        .background(Color.vyumAccentSoft, in: .rect(cornerRadius: Radius.control, style: .continuous))
    }
}

private struct WeekSummaryLine: View {
    let summary: ProgressSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.vyumTextPrimary)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DisclosureChevron()
            }
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: TouchTarget.minimum)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Progress")
    }

    private var text: String {
        switch summary.activeDaysThisWeek {
        case 0: "No sessions yet this week. A few minutes is a great start."
        case 1: "1 active day this week · \(summary.minutesThisWeek) min"
        default: "\(summary.activeDaysThisWeek) active days this week · \(summary.minutesThisWeek) min"
        }
    }
}

#Preview {
    TodayView(selectedTab: .constant(.home))
        .environment(AppModel.preview())
}
