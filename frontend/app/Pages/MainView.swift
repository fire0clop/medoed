// Pages/MainView.swift

import SwiftUI

struct MainView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("DiabetAI")
                    .font(.largeTitle.bold())

                Text("Вы успешно авторизованы")
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    appState.logout()
                } label: {
                    Text("Выйти")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
