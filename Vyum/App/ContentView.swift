//
//  ContentView.swift
//  Vyum
//
//  Created by user@72 on 09/10/26.
//

import SwiftUI

/// Root: loads content, then shows onboarding or the main tabs.
/// The session player is presented here so any screen can start one.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        content
            .tint(Color.vyumAccentFill)
            .preferredColorScheme(.dark)
            .task { appModel.load() }
            .fullScreenCover(item: $appModel.activeSession) { session in
                SessionView(session: session)
            }
    }

    @ViewBuilder private var content: some View {
        switch appModel.loadState {
        case .loading:
            ProgressView("Loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .vyumScreenBackground()
        case .failed(let message):
            StateMessage(
                title: "Something went wrong",
                message: message,
                systemImage: "exclamationmark.triangle"
            ) {
                Button("Try again") { appModel.load() }
                    .buttonStyle(.vyumPrimary)
            }
            .frame(maxHeight: .infinity)
            .vyumScreenBackground()
        case .loaded:
            if appModel.preferences.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView(reminders: appModel.reminders)
            }
        }
    }
}

#Preview("Main") {
    ContentView()
        .environment(AppModel.preview())
}

#Preview("Onboarding") {
    ContentView()
        .environment(AppModel.preview(onboarded: false))
}
