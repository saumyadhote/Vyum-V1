import SwiftUI
import UIKit

/// Full-screen guided session. Keeps the screen awake, pauses when the app
/// leaves the foreground, and saves progress so the session can be resumed.
struct SessionView: View {
    let session: SessionViewModel

    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var isConfirmingEnd = false
    @State private var resumeAfterConfirm = false

    var body: some View {
        Group {
            if session.isFinished {
                SessionCompleteView(session: session) {
                    appModel.sessionDismissed(session)
                }
            } else {
                player
            }
        }
        .vyumScreenBackground()
        .task { await session.run() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            session.pause()
            appModel.saveProgress(of: session)
        }
        .onChange(of: session.cueKey) {
            appModel.saveProgress(of: session)
            announceCue()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: session.cueKey) { _, _ in !session.isFinished }
        .sensoryFeedback(.success, trigger: session.isFinished) { _, finished in finished }
    }

    private var player: some View {
        VStack(spacing: 0) {
            SessionHeader(session: session) {
                resumeAfterConfirm = !session.isPaused
                session.pause()
                isConfirmingEnd = true
            }
            ScrollView {
                SessionExerciseContent(session: session)
                    .id(session.index)
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.bottom, Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            SessionControls(session: session)
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.vertical, Spacing.sm)
                .background(Color.vyumBackground)
        }
        // An alert rather than a confirmation dialog, so "Keep going" is always visible.
        .alert("End this session?", isPresented: $isConfirmingEnd) {
            Button("Keep going", role: .cancel) {
                if resumeAfterConfirm { session.resume() }
            }
            Button("End session", role: .destructive) { session.end() }
        } message: {
            Text("Anything you've done so far will still be saved.")
        }
    }

    private func announceCue() {
        let exercise = session.currentExercise
        let message: String
        if session.isFinished {
            message = "Session complete."
        } else if session.isOnSecondSide {
            message = "Switch sides."
        } else if session.stage == .getReady {
            message = "Get ready: \(exercise.name). \(exercise.repsGuide)."
        } else {
            message = "Begin \(exercise.name)."
        }
        AccessibilityNotification.Announcement(message).post()
    }
}

// MARK: - Header

private struct SessionHeader: View {
    let session: SessionViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                        .background(Color.vyumSurfaceEmphasis, in: .circle)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityLabel("End session")
                .accessibilityIdentifier("session.close")

                Spacer()

                Text("Exercise \(session.index + 1) of \(session.plan.exercises.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.vyumTextSecondary)

                Spacer()

                // Balances the close button so the title stays centred.
                Color.clear.frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                    .accessibilityHidden(true)
            }
            SegmentedProgress(total: session.plan.exercises.count, current: session.index, currentProgress: session.stage == .active ? session.stageProgress : 0)
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.sm)
    }
}

/// One segment per exercise: filled when done, partially filled for the current one.
private struct SegmentedProgress: View {
    let total: Int
    let current: Int
    let currentProgress: Double

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(0..<total, id: \.self) { index in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.vyumSeparator)
                        Capsule()
                            .fill(Color.vyumTextPrimary)
                            .frame(width: proxy.size.width * fill(for: index))
                    }
                }
                .frame(height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Session progress")
        .accessibilityValue("Exercise \(current + 1) of \(total)")
    }

    private func fill(for index: Int) -> Double {
        if index < current { return 1 }
        if index == current { return min(1, max(0, currentProgress)) }
        return 0
    }
}

// MARK: - Exercise content

private struct SessionExerciseContent: View {
    let session: SessionViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var exercise: Exercise { session.currentExercise }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            IllustrationPlate(
                imageName: exercise.illustration,
                description: exercise.illustrationDescription,
                // Leave room for the instructions when text is very large.
                maxHeight: dynamicTypeSize.isAccessibilitySize ? 160 : 240
            )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(stageTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.vyumTextSecondary)
                Text(exercise.name)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.vyumTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(exercise.repsGuide)
                    .font(.title3)
                    .foregroundStyle(Color.vyumTextPrimary)
            }

            TimerReadout(session: session)

            if session.stage == .getReady {
                Button("Start now") { session.startNow() }
                    .buttonStyle(.vyumSecondary)
                    .disabled(session.isPaused)
                    .accessibilityIdentifier("session.startNow")
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("How to do it")
                    .font(.headline)
                    .foregroundStyle(Color.vyumTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                NumberedSteps(steps: exercise.steps)
            }

            if let caution = exercise.cautions.first {
                NoteBox(title: "Take care", message: caution, systemImage: "hand.raised")
            }
        }
        .padding(.top, Spacing.xs)
    }

    private var stageTitle: String {
        if session.isPaused { return "Paused" }
        switch session.stage {
        case .getReady: return "Get ready"
        case .active:
            if exercise.bothSides {
                return session.isOnSecondSide ? "Now switch sides" : "First side"
            }
            return "Now moving"
        }
    }
}

private struct TimerReadout: View {
    let session: SessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(DurationText.clock(session.remainingSeconds))
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(session.isPaused ? Color.vyumTextSecondary : Color.vyumTextPrimary)
                Text(session.stage == .getReady ? "until start" : "remaining")
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
            }
            ProgressView(value: session.stageProgress)
                .tint(Color.vyumAccentFill)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.stage == .getReady ? "Starts in" : "Time")
        .accessibilityValue(DurationText.spokenRemaining(session.remainingSeconds) + (session.isPaused ? ", paused" : ""))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

struct NumberedSteps: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(steps.enumerated()), id: \.offset) { offset, step in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text("\(offset + 1)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.vyumTextPrimary)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Color.vyumAccentSoft, in: .circle)
                        .accessibilityHidden(true)
                    Text(step)
                        .font(.body)
                        .foregroundStyle(Color.vyumTextPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(offset + 1): \(step)")
            }
        }
    }
}

// MARK: - Controls

private struct SessionControls: View {
    let session: SessionViewModel

    var body: some View {
        HStack(alignment: .bottom) {
            ControlButton(title: "Back", systemImage: "backward.end.fill", identifier: "session.back") {
                session.goBack()
            }
            .disabled(!session.canGoBack)

            Spacer()

            Button(action: session.togglePause) {
                VStack(spacing: Spacing.xxs) {
                    Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .foregroundStyle(Color.vyumOnAccent)
                        .frame(width: TouchTarget.primaryControl, height: TouchTarget.primaryControl)
                        .background(Color.vyumAccentFill, in: .circle)
                    Text(session.isPaused ? "Resume" : "Pause")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.vyumTextPrimary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("session.pauseResume")

            Spacer()

            ControlButton(title: "Skip", systemImage: "forward.end.fill", identifier: "session.skip") {
                session.skip()
            }
        }
    }
}

private struct ControlButton: View {
    let title: String
    let systemImage: String
    let identifier: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 56, height: 56)
                    .background(Color.vyumSurfaceEmphasis, in: .circle)
                    .overlay(Circle().strokeBorder(Color.vyumSeparator, lineWidth: 1))
                Text(title)
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(isEnabled ? Color.vyumTextPrimary : Color.vyumTextSecondary)
            .opacity(isEnabled ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    SessionView(session: .preview())
        .environment(AppModel.preview())
}
