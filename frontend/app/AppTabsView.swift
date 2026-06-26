import SwiftUI
import Combine

/// Общий роутер для переключения экранов из любого места.
@MainActor
final class TabRouter: ObservableObject {
    @Published var selected: AppTabsView.Tab = .calculator
}

struct AppTabsView: View {

    @StateObject private var router = TabRouter()

    enum Tab: Hashable { case calculator, dishes, diary, profile }

    var body: some View {
        Group {
            switch router.selected {
            case .calculator:
                CalculatorView()
            case .dishes:
                DishesView()
            case .profile:
                ProfileView()
            case .diary:
                DiaryPlaceholderView()
            }
        }
        .environmentObject(router)
    }
}
