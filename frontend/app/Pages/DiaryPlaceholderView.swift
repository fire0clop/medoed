import SwiftUI

struct DiaryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "book.closed").font(.system(size: 42))
                Text("Дневник").font(.title.bold())
                Text("Заглушка страницы").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Дневник")
        }
    }
}
