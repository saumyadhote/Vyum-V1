import SwiftUI

/// What's in a routine, with a single action to start it.
struct RoutineDetailView: View {
    let routineID: String
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if let routine = appModel.library?.routine(id: routineID), let plan = appModel.plan(for: routine) {
            content(routine: routine, plan: plan)
        } else {
            ContentUnavailableView(
                "Session not found",
                systemImage: "questionmark.circle",
                description: Text("This session isn't available any more.")
            )
            .vyumScreenBackground()
        }
    }

    private func content(routine: Routine, plan: SessionPlan) -> some View {
        let isProgramme = routine.id == Routine.weekOneID
        return List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if isProgramme {
                        Text("Your programme")
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.vyumTextSecondary)
                    }
                    Text(routine.summary)
                        .font(.body)
                        .foregroundStyle(Color.vyumTextSecondary)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Spacing.md) { facts(plan) }
                        VStack(alignment: .leading, spacing: Spacing.xxs) { facts(plan) }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.xxs, bottom: Spacing.xs, trailing: Spacing.xxs))
            }

            if let intro = routine.intro {
                Section {
                    Label {
                        Text(intro)
                            .font(.subheadline)
                            .foregroundStyle(Color.vyumTextPrimary)
                    } icon: {
                        Image(systemName: "exclamationmark.bubble")
                            .foregroundStyle(Color.vyumAccentFill)
                    }
                    .listRowBackground(Color.vyumSurface)
                }
            }

            if plan.positions.contains(.floor) {
                Section {
                    Label("One exercise is on your hands and knees. You can skip it during the session, or try the seated version described in its details.", systemImage: "info.circle")
                        .font(.subheadline)
                        .listRowBackground(Color.vyumSurface)
                }
            }

            Section {
                ForEach(Array(plan.exercises.enumerated()), id: \.offset) { offset, exercise in
                    NavigationLink(value: AppRoute.exercise(exercise.id)) {
                        StepRow(number: offset + 1, exercise: exercise)
                    }
                    .listRowBackground(Color.vyumSurface)
                }
            } header: {
                Text("In this session")
            } footer: {
                if isProgramme {
                    Text("Consistent with NHS and Cleveland Clinic guidance on gentle neck movement. A conservative starter routine, not personally prescribed physiotherapy.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .vyumScreenBackground()
        .navigationTitle(routine.title)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Button {
                appModel.start(plan)
            } label: {
                Text("Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Color.vyumAccentFill)
            .foregroundStyle(Color.vyumOnAccent)
            .accessibilityLabel("Start \(routine.title)")
            .accessibilityIdentifier("routine.start")
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.sm)
            .background(Color.vyumBackground)
        }
    }

    @ViewBuilder
    private func facts(_ plan: SessionPlan) -> some View {
        Label("\(plan.roundedMinutes) min", systemImage: "clock")
        Label(plan.exercises.count == 1 ? "1 exercise" : "\(plan.exercises.count) exercises", systemImage: "list.bullet")
        if let equipment = equipmentText(plan) {
            Label(equipment, systemImage: "checklist")
        }
    }

    /// Everything the routine needs, in the order it's first used.
    private func equipmentText(_ plan: SessionPlan) -> String? {
        var seen: [String] = []
        for title in plan.exercises.compactMap(\.equipment.title) where !seen.contains(title) {
            seen.append(title)
        }
        return seen.isEmpty ? nil : seen.joined(separator: " & ")
    }
}

private struct StepRow: View {
    let number: Int
    let exercise: Exercise

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.vyumAccentFill)
                .frame(minWidth: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(Color.vyumTextPrimary)
                Text("\(DurationText.short(exercise.duration)) · \(exercise.repsGuide)")
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(exercise.name), \(DurationText.short(exercise.duration)), \(exercise.repsGuide)")
    }
}

#Preview {
    NavigationStack {
        RoutineDetailView(routineID: "week-1")
    }
    .environment(AppModel.preview())
}
