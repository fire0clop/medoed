// AppState.swift
import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {

    @Published var isAuthorized: Bool = false
    @Published var isLoading: Bool = true
    @Published var userEmail: String? = UserDefaults.standard.string(forKey: "userEmail")

    private let tokenService = TokenService()
    private let profileStorage = ProfileStorage()

    func setUserEmail(_ email: String?) {
        userEmail = email
        if let email {
            UserDefaults.standard.set(email, forKey: "userEmail")
        } else {
            UserDefaults.standard.removeObject(forKey: "userEmail")
        }
    }

    init() {
        Task {
            await bootstrap()
        }
    }

    func bootstrap() async {
        defer { isLoading = false }

        // DEV: bypass for screenshots
        if UserDefaults.standard.bool(forKey: "dev_auth") {
            isAuthorized = true
            return
        }

        // ❌ нет refresh токена → точно не авторизован
        guard tokenService.hasRefreshToken else {
            isAuthorized = false
            return
        }

        do {
            try await tokenService.refreshAccessToken()
            isAuthorized = true
        } catch APIError.unauthorized {
            tokenService.clearTokens()
            isAuthorized = false
        } catch {
            // Сеть / таймаут: сессия в Keychain есть — пускаем в приложение с кэшем (профиль и т.д.)
            isAuthorized = true
        }
    }

    func logout() {
        let refresh = tokenService.peekRefreshToken()

        if let userId = tokenService.userId {
            profileStorage.clear(userId: userId)
        }

        tokenService.clearTokens()
        setUserEmail(nil)
        isAuthorized = false

        if let refresh {
            Task {
                try? await AuthAPI().logout(refreshToken: refresh)
            }
        }
    }

    /// Полностью удаляет аккаунт на сервере и очищает локальное хранилище.
    func deleteAccount() async throws {
        try await AuthAPI().deleteAccount()

        if let userId = tokenService.userId {
            profileStorage.clear(userId: userId)
        }
        tokenService.clearTokens()
        setUserEmail(nil)
        isAuthorized = false
    }
}
