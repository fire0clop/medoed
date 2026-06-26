// RootView.swift

import SwiftUI

struct RootView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoading {
                SplashView()
            } else if appState.isAuthorized {
                AppTabsView()   // меню только после входа
            } else {
                AuthView()      // без меню
            }
        }
    }
}
