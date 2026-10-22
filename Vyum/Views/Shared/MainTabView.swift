import SwiftUI

enum AppTab: Hashable {
    case home
    case exercises
    case posture
    case progress
}

/// Destinations pushed inside any tab's navigation stack.
enum AppRoute: Hashable {
    case routine(String)
    case exercise(String)
    case area(BodyArea)
}

/// The bottom navigation. A system tab bar, so it gets Liquid Glass,
/// accessibility and size-class behaviour for free.
struct MainTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView()
            }
            Tab("Exercises", systemImage: "figure.cooldown", value: .exercises) {
                LibraryView()
            }
            Tab("Posture", systemImage: "camera.viewfinder", value: .posture) {
                PostureCheckView()
            }
            // Settings opens from the gear button on Progress.
            Tab("Progress", systemImage: "calendar", value: .progress) {
                ProgressTabView(selectedTab: $selection)
            }
        }
    }
}

extension View {
    /// Registers every pushable screen. Applied once per navigation stack.
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .routine(let id): RoutineDetailView(routineID: id)
            case .exercise(let id): ExerciseDetailView(exerciseID: id)
            case .area(let area): AreaExercisesView(area: area)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppModel.preview())
}
