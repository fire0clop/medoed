// SplashView.swift

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("main-icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 157, height: 143)

                Spacer()

                VStack(spacing: 14) {
                    Text("Разработано с учётом медицинских рекомендаций для контроля диабета каждый день.")
                        .font(.gilroy(12))
                        .foregroundColor(Color(red: 0.486, green: 0.486, blue: 0.486))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 62)

                    Text("MEDOED")
                        .font(.gilroy(28, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(.bottom, 56)
            }
        }
    }
}
