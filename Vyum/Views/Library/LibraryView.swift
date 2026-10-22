import SwiftUI

/// The exercise catalogue: guided sessions, then every exercise.
/// Search sits in the navigation bar; position and body-area filters live in the toolbar menu.
struct LibraryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = LibraryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let library = appModel.library {
                    catalogue(library)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .vyumScreenBackground()
            .navigationTitle("Exercises")
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search exercises or body areas"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    FilterMenu(position: $viewModel.position, area: $viewModel.area)
                }
            }
            .appRouteDestinations()
        }
    }

    @ViewBuilder
    private func catalogue(_ library: ExerciseLibrary) -> some View {
        let results = viewModel.results(in: library)
        if viewModel.isFiltering && results.isEmpty {
            ContentUnavailableView {
                Label("No matching exercises", systemImage: "magnifyingglass")
            } description: {
                Text("Try a different word, like “neck” or “standing”.")
            } actions: {
                Button("Clear search and filters") { viewModel.clearFilters() }
                    .buttonStyle(.bordered)
            }
        } else {
            List {
                if !viewModel.isFiltering {
                    Section("Guided sessions") {
                        ForEach(library.routines) { routine in
                            NavigationLink(value: AppRoute.routine(routine.id)) {
                                GuidedSessionRow(routine: routine, plan: SessionPlan(routine: routine, library: library))
                            }
                            .listRowBackground(Color.vyumSurface)
                        }
                    }
                }

                Section {
                    ForEach(results) { exercise in
                        NavigationLink(value: AppRoute.exercise(exercise.id)) {
                            CatalogueExerciseRow(exercise: exercise)
                        }
                        .listRowBackground(Color.vyumSurface)
                    }
                } header: {
                    Text(viewModel.isFiltering ? resultsTitle(results.count) : "All exercises")
                }
            }
            .listStyle(.insetGrouped)
            .headerProminence(.increased)
            .scrollContentBackground(.hidden)
        }
    }

    private func resultsTitle(_ count: Int) -> String {
        let base = count == 1 ? "1 exercise" : "\(count) exercises"
        let filters = [viewModel.position?.title, viewModel.area?.title].compactMap { $0 }
        return filters.isEmpty ? base : "\(base) · \(filters.joined(separator: ", "))"
    }
}

/// Position and body-area filters, as a native menu with checkmarks.
private struct FilterMenu: View {
    @Binding var position: ExercisePosition?
    @Binding var area: BodyArea?

    var body: some View {
        Menu {
            Picker("Position", selection: $position) {
                Text("Any position").tag(ExercisePosition?.none)
                ForEach(ExercisePosition.allCases) { position in
                    Label(position.title, systemImage: position.systemImage)
                        .tag(Optional(position))
                }
            }
            .pickerStyle(.inline)

            Picker("Body area", selection: $area) {
                Text("All body areas").tag(BodyArea?.none)
                ForEach(BodyArea.allCases) { area in
                    Label(area.title, systemImage: area.systemImage)
                        .tag(Optional(area))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: isActive
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filter")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("library.filter")
    }

    private var isActive: Bool { position != nil || area != nil }

    private var accessibilityValue: String {
        let parts = [position?.title, area?.title].compactMap { $0 }
        return parts.isEmpty ? "No filters" : parts.joined(separator: ", ")
    }
}

private struct GuidedSessionRow: View {
    let routine: Routine
    let plan: SessionPlan

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if routine.id == Routine.weekOneID {
                Text("Your programme")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.vyumAccentFill)
            }
            Text(routine.title)
                .font(.headline)
                .foregroundStyle(Color.vyumTextPrimary)
            Text(routine.summary)
                .font(.subheadline)
                .foregroundStyle(Color.vyumTextSecondary)
                .lineLimit(2)
            HStack(spacing: Spacing.md) {
                Label("\(plan.roundedMinutes) min", systemImage: "clock")
                Label(plan.exercises.count == 1 ? "1 exercise" : "\(plan.exercises.count) exercises", systemImage: "list.bullet")
            }
            .font(.footnote)
            .foregroundStyle(Color.vyumTextSecondary)
            .padding(.top, 2)
        }
        .padding(.vertical, Spacing.xxs)
    }
}

/// Catalogue row: the exercise's figure, then name, summary and facts.
struct CatalogueExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: Spacing.md) {
            ExerciseFigure(exerciseID: exercise.id)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(Color.vyumTextPrimary)
                Text(exercise.summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
                    .lineLimit(2)
                HStack(spacing: Spacing.md) {
                    Label(DurationText.short(exercise.duration), systemImage: "clock")
                    Label(exercise.position.title, systemImage: exercise.position.systemImage)
                }
                .font(.footnote)
                .foregroundStyle(Color.vyumTextSecondary)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

/// The single figure for an exercise, or a plain blank box when there isn't one yet.
struct ExerciseFigure: View {
    let exerciseID: String
    @ScaledMetric(relativeTo: .headline) private var width: CGFloat = 64

    var body: some View {
        Group {
            if let name = Artwork.figure(for: exerciseID) {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: width * 1.3)
                    .background(Color.vyumSurface)
            } else {
                Color.vyumSurfaceEmphasis
                    .frame(width: width, height: width * 1.3)
            }
        }
        .clipShape(.rect(cornerRadius: Radius.control, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Exercises for one body area.
struct AreaExercisesView: View {
    let area: BodyArea
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let exercises = appModel.library?.exercises.filter { $0.bodyAreas.contains(area) } ?? []
        Group {
            if exercises.isEmpty {
                ContentUnavailableView(
                    "Nothing here yet",
                    systemImage: area.systemImage,
                    description: Text("There are no exercises for this area yet.")
                )
            } else {
                List {
                    Section(exercises.count == 1 ? "1 exercise" : "\(exercises.count) exercises") {
                        ForEach(exercises) { exercise in
                            NavigationLink(value: AppRoute.exercise(exercise.id)) {
                                CatalogueExerciseRow(exercise: exercise)
                            }
                            .listRowBackground(Color.vyumSurface)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .vyumScreenBackground()
        .navigationTitle(area.title)
    }
}

#Preview {
    LibraryView()
        .environment(AppModel.preview())
}
