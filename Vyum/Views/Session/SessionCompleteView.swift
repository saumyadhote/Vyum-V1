import SwiftUI

/// Shown when a session ends, whether finished or ended early.
struct SessionCompleteView: View {
    let session: SessionViewModel
    let onDone: () -> Void

    private var completedAll: Bool {
        session.status == .finished(completedAll: true)
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.vyumTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.body)
                    .foregroundStyle(Color.vyumTextSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: Spacing.md) {
                Stat(value: "\(session.completedCount) of \(session.plan.exercises.count)", label: "Exercises")
                Stat(value: DurationText.short(session.activeSeconds), label: "Moving")
            }

            Spacer()

            Button("Done", action: onDone)
                .buttonStyle(.vyumPrimary)
                .accessibilityIdentifier("session.done")
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.bottom, Spacing.md)
    }

    private var title: String {
        if completedAll { return "Session complete" }
        return session.result == nil ? "Session ended" : "Nice work"
    }

    private var message: String {
        if completedAll {
            return "\(session.plan.title) is done. Take a moment to notice how you feel."
        }
        if session.result == nil {
            return "This one was too short to save. Come back whenever you're ready."
        }
        return "Every bit of movement counts. We've saved what you did."
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.vyumTextPrimary)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.vyumTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(Color.vyumSurface, in: .rect(cornerRadius: Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(Color.vyumSeparator, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let session = SessionViewModel.preview()
    session.end()
    return SessionCompleteView(session: session) {}
        .vyumScreenBackground()
}
