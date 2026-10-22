import SwiftUI

/// Four short steps. Only the first is required; everything can be changed later in Settings.
struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: OnboardingViewModel

    init(reminders: ReminderScheduling) {
        _viewModel = State(initialValue: OnboardingViewModel(reminders: reminders))
    }

    var body: some View {
        OnboardingFlow(viewModel: viewModel) {
            appModel.completeOnboarding(with: viewModel.draft)
        }
        .vyumScreenBackground()
    }
}

private struct OnboardingFlow: View {
    @Bindable var viewModel: OnboardingViewModel
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    switch viewModel.step {
                    case .welcome: WelcomeStep()
                    case .focus: FocusStep(viewModel: viewModel)
                    case .preferences: PreferencesStep(viewModel: viewModel)
                    case .reminder: ReminderStep(viewModel: viewModel)
                    }
                }
                .id(viewModel.step)
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .vyumScreenBackground()
            .safeAreaInset(edge: .bottom) {
                actions
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.vyumBackground)
            }
            .toolbar {
                if viewModel.canGoBack {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.goBack()
                        } label: {
                            Label("Back", systemImage: "chevron.backward")
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Step \(viewModel.stepNumber) of \(viewModel.stepCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.vyumTextSecondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private var actions: some View {
        switch viewModel.step {
        case .welcome:
            Button("Get started", action: advance)
                .buttonStyle(.vyumPrimary)
                .accessibilityIdentifier("onboarding.start")
        case .focus:
            Button(viewModel.draft.focusAreas.isEmpty ? "Skip for now" : "Continue", action: advance)
                .buttonStyle(.vyumPrimary)
                .accessibilityIdentifier("onboarding.continue")
        case .preferences:
            Button("Continue", action: advance)
                .buttonStyle(.vyumPrimary)
                .accessibilityIdentifier("onboarding.continue")
        case .reminder:
            VStack(spacing: Spacing.sm) {
                if viewModel.reminderDenied {
                    Button("Continue without reminder", action: onFinish)
                        .buttonStyle(.vyumPrimary)
                } else {
                    Button {
                        Task {
                            if await viewModel.enableReminder() { onFinish() }
                        }
                    } label: {
                        if viewModel.isRequestingReminder {
                            ProgressView()
                        } else {
                            Text("Turn on reminder")
                        }
                    }
                    .buttonStyle(.vyumPrimary)
                    .disabled(viewModel.isRequestingReminder)
                    .accessibilityIdentifier("onboarding.enableReminder")

                    Button("Not now") {
                        viewModel.skipReminder()
                        onFinish()
                    }
                    .buttonStyle(.vyumSecondary)
                    .accessibilityIdentifier("onboarding.skipReminder")
                }
            }
        }
    }

    private func advance() {
        viewModel.goForward()
    }
}

// MARK: - Steps

private struct StepHeading: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.vyumTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Image("posture-journey")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 180)
                .accessibilityLabel("A person going from slouched on a stool to sitting tall, standing straight, and celebrating a week of progress.")
            StepHeading(
                title: "Small movements for long days at a desk",
                message: "Short, guided exercises to help you sit taller, move more easily and stay strong for everyday life. No equipment needed."
            )
            NoteBox(
                title: "Before you begin",
                message: "Vyum offers general movement guidance, not medical advice. Move within a comfortable range and stop if anything hurts. If you have an injury, a health condition or have had recent surgery, check with your doctor or physiotherapist first."
            )
        }
        .padding(.top, Spacing.md)
    }
}

private struct FocusStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            StepHeading(
                title: "Where would you like to focus?",
                message: "Choose any that feel stiff or that you'd like to strengthen. You can change this later."
            )
            VStack(spacing: Spacing.sm) {
                ForEach(BodyArea.allCases) { area in
                    SelectableRow(
                        title: area.title,
                        systemImage: area.systemImage,
                        imageName: area.artworkName,
                        isSelected: viewModel.draft.focusAreas.contains(area)
                    ) {
                        viewModel.toggleFocus(area)
                    }
                    .accessibilityIdentifier("onboarding.focus.\(area.rawValue)")
                }
            }
        }
        .padding(.top, Spacing.md)
        .sensoryFeedback(.selection, trigger: viewModel.draft.focusAreas)
    }
}

private struct PreferencesStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            StepHeading(
                title: "How do you like to move?",
                message: "We'll use this to suggest a session each day."
            )

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Position")
                    .font(.headline)
                    .foregroundStyle(Color.vyumTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                SelectableRow(
                    title: PositionPreference.seatedOnly.title,
                    subtitle: "Everything can be done from your chair",
                    systemImage: "chair",
                    isSelected: viewModel.draft.positionPreference == .seatedOnly,
                    isRadio: true
                ) { viewModel.draft.positionPreference = .seatedOnly }
                SelectableRow(
                    title: PositionPreference.any.title,
                    subtitle: "Includes some standing exercises",
                    systemImage: "figure.stand",
                    isSelected: viewModel.draft.positionPreference == .any,
                    isRadio: true
                ) { viewModel.draft.positionPreference = .any }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Session length")
                    .font(.headline)
                    .foregroundStyle(Color.vyumTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                ForEach(SessionLength.allCases) { length in
                    SelectableRow(
                        title: length.title,
                        systemImage: "clock",
                        isSelected: viewModel.draft.sessionLength == length,
                        isRadio: true
                    ) { viewModel.draft.sessionLength = length }
                }
            }
        }
        .padding(.top, Spacing.md)
        .sensoryFeedback(.selection, trigger: viewModel.draft)
    }
}

private struct ReminderStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            StepHeading(
                title: "Want a gentle daily reminder?",
                message: "One notification a day at a time that suits you. You can change or turn it off in Settings."
            )

            DatePicker("Reminder time", selection: reminderDate, displayedComponents: .hourAndMinute)
                .font(.headline)
                .foregroundStyle(Color.vyumTextPrimary)
                .padding(Spacing.md)
                .background(Color.vyumSurface, in: .rect(cornerRadius: Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(Color.vyumSeparator, lineWidth: 1)
                )

            if viewModel.reminderDenied {
                NoteBox(
                    title: "Notifications are off for Vyum",
                    message: "You can allow them in the Settings app under Notifications, then turn the reminder on in Vyum's settings.",
                    systemImage: "bell.slash"
                )
            }
        }
        .padding(.top, Spacing.md)
    }

    private var reminderDate: Binding<Date> {
        Binding {
            let time = viewModel.draft.reminderTime
            return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            viewModel.draft.reminderTime = ReminderTime(hour: parts.hour ?? 11, minute: parts.minute ?? 0)
        }
    }
}

#Preview {
    OnboardingView(reminders: PreviewReminderService())
        .environment(AppModel.preview(onboarded: false))
}
