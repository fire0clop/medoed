// DiabetAIApp.swift

import SwiftUI

@main
struct DiabetAIApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
