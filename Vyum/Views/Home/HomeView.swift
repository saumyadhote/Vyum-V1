import SwiftUI

/// Home: wordmark, the mascot, and one routine to start.
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mascot = MascotViewModel(tiltSource: MotionManager())

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        Spacer(minLength: Spacing.xl)
                        MascotView(viewModel: mascot)
                        Spacer(minLength: Spacing.xl)
                        nextRoutine
                    }
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.vertical, Spacing.md)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .vyumScreenBackground()
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        // Sensors run only while Home is on screen, the app is active, and motion is welcome.
        .task(id: isTiltActive) {
            guard isTiltActive else { return }
            await mascot.trackTilt()
        }
    }

    private var isTiltActive: Bool {
        scenePhase == .active && !reduceMotion
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("gogo")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("better posture, better you")
                .font(.subheadline)
                .foregroundStyle(Color.vyumTextSecondary)
        }
    }

    @ViewBuilder private var nextRoutine: some View {
        if let snapshot = appModel.resumableSnapshot {
            RoutineCard(
                eyebrow: "Pick up where you left off",
                title: snapshot.plan.title,
                detail: "\(snapshot.completedCount) of \(snapshot.plan.exercises.count) done"
            ) {
                appModel.resumeInterruptedSession()
            }
            .contextMenu {
                Button("Discard", systemImage: "trash", role: .destructive) {
                    appModel.discardResumableSession()
                }
            }
            .accessibilityHint("Resumes your unfinished session")
            .accessibilityIdentifier("today.resume")
        } else if let routine = featuredRoutine, let plan = appModel.plan(for: routine) {
            RoutineCard(
                eyebrow: "Your next routine",
                title: routine.title,
                detail: "\(plan.roundedMinutes) min · \(exerciseCount(plan.exercises.count))"
            ) {
                appModel.start(plan)
            }
            .accessibilityHint("Starts the session")
            .accessibilityIdentifier("today.start")
        }
    }

    /// The Week 1 programme while it exists, otherwise the daily suggestion.
    private var featuredRoutine: Routine? {
        appModel.library?.routine(id: Routine.weekOneID) ?? appModel.todaysRoutine
    }

    private func exerciseCount(_ count: Int) -> String {
        count == 1 ? "1 exercise" : "\(count) exercises"
    }
}

#Preview {
    HomeView()
        .environment(AppModel.preview())
}
