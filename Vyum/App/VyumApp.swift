//
//  VyumApp.swift
//  Vyum
//
//  Created by user@72 on 09/10/26.
//

import SwiftUI
import UIKit

@main
struct VyumApp: App {
    @State private var appModel: AppModel

    init() {
        // SwiftUI has no API for navigation title colour; titles use the brand ink.
        let ink = UIColor(resource: .brandTextPrimary)
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: ink]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: ink]

        // UI tests launch with a clean, throwaway state.
        let isUITesting = CommandLine.arguments.contains("-uiTestingReset")
        if isUITesting, let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }

        // If the store can't be opened the app still works; Progress explains the problem.
        let historyStore = try? SwiftDataSessionHistoryStore(
            container: SwiftDataSessionHistoryStore.makeContainer(inMemory: isUITesting)
        )
        _appModel = State(initialValue: AppModel(
            libraryService: BundledExerciseLibraryService(),
            preferencesStore: UserDefaultsPreferencesStore(),
            historyStore: historyStore,
            snapshotStore: UserDefaultsSnapshotStore(),
            reminders: LocalReminderService()
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
    }
}
