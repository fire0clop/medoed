// API/AuthAPI.swift

import Foundation

final class AuthAPI {

    private let api = APIClient.shared

    // MARK: - Registration

    func sendRegisterCode(email: String) async throws {
        struct Body: Encodable { let email: String }
        struct Response: Decodable { let ok: Bool }

        let _: Response = try await api.request(
            "/auth/email/send-code",
            method: "POST",
            body: Body(email: email)
        )
    }

    func confirmRegister(
        email: String,
        password: String,
        code: String
    ) async throws -> TokenPair {

        struct Body: Encodable {
            let email: String
            let password: String
            let code: String
        }

        return try await api.request(
            "/auth/email/confirm-register",
            method: "POST",
            body: Body(email: email, password: password, code: code)
        )
    }

    // MARK: - Login

    func login(
        email: String,
        password: String
    ) async throws -> TokenPair {

        struct Body: Encodable {
            let email: String
            let password: String
        }

        return try await api.request(
            "/auth/email/login",
            method: "POST",
            body: Body(email: email, password: password)
        )
    }

    // MARK: - Google

    func loginWithGoogle(idToken: String) async throws -> TokenPair {
        struct Body: Encodable { let id_token: String }
        // ⚠️ поле называется id_token, потому что на бэке GoogleAuthRequest: id_token
        return try await api.request(
            "/auth/google",
            method: "POST",
            body: Body(id_token: idToken)
        )
    }

    // MARK: - Apple

    func loginWithApple(identityToken: String) async throws -> TokenPair {
        struct Body: Encodable { let identity_token: String }
        return try await api.request(
            "/auth/apple",
            method: "POST",
            body: Body(identity_token: identityToken)
        )
    }

    // MARK: - Logout

    /// Инвалидирует сессию на сервере (см. readme-backend: `POST /auth/logout`).
    func logout(refreshToken: String) async throws {
        struct Body: Encodable { let refresh_token: String }
        struct OkResponse: Decodable { let ok: Bool }

        let _: OkResponse = try await api.request(
            "/auth/logout",
            method: "POST",
            body: Body(refresh_token: refreshToken),
            authorized: false,
            retry: false
        )
    }

    // MARK: - Delete account

    /// Полностью удаляет аккаунт и все данные пользователя (`DELETE /auth/account`).
    func deleteAccount() async throws {
        struct OkResponse: Decodable { let ok: Bool }
        let _: OkResponse = try await api.request(
            "/auth/account",
            method: "DELETE",
            authorized: true,
            retry: false
        )
    }
}
