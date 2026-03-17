// Services/AuthService.swift

import Foundation
import Combine
import AuthenticationServices

@MainActor
final class AuthService: ObservableObject {

    enum Mode {
        case login
        case register
        case confirmCode
    }

    @Published var mode: Mode = .login
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Email последнего успешного входа (для записи в AppState).
    @Published var lastLoggedInEmail: String?

    private let api = AuthAPI()

    /// Декодирует email из payload JWT (id_token Google/Apple) без верификации подписи.
    private static func emailFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard
            let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return (json["email"] as? String)?.lowercased()
    }
    private let tokenService = TokenService()
    private let googleAuth = GoogleAuthService()
    private let appleAuth = AppleAuthService()

    // MARK: - Helpers

    private func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizePassword(_ password: String) -> String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeCode(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.filter { $0.isNumber })
    }

    // MARK: - Registration

    func startRegistration(email: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let cleanEmail = normalizeEmail(email)

        do {
            try await api.sendRegisterCode(email: cleanEmail)
            mode = .confirmCode
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmRegistration(
        email: String,
        password: String,
        code: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let cleanEmail = normalizeEmail(email)
        let cleanPassword = normalizePassword(password)
        let cleanCode = normalizeCode(code)

        do {
            let tokens = try await api.confirmRegister(
                email: cleanEmail,
                password: cleanPassword,
                code: cleanCode
            )
            tokenService.saveTokens(
                access: tokens.access_token,
                refresh: tokens.refresh_token
            )
            lastLoggedInEmail = cleanEmail
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Email Login

    func login(
        email: String,
        password: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let cleanEmail = normalizeEmail(email)
        let cleanPassword = normalizePassword(password)

        do {
            let tokens = try await api.login(
                email: cleanEmail,
                password: cleanPassword
            )
            tokenService.saveTokens(
                access: tokens.access_token,
                refresh: tokens.refresh_token
            )
            lastLoggedInEmail = cleanEmail
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Apple Login

    func loginWithApple() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let identityToken = try await appleAuth.signIn()
            let tokens = try await api.loginWithApple(identityToken: identityToken)
            tokenService.saveTokens(
                access: tokens.access_token,
                refresh: tokens.refresh_token
            )
            lastLoggedInEmail = Self.emailFromJWT(identityToken)
            return true
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // пользователь отменил — молча игнорируем
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Google Login

    func loginWithGoogle() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let idToken = try await googleAuth.signIn()
            let tokens = try await api.loginWithGoogle(idToken: idToken)

            tokenService.saveTokens(
                access: tokens.access_token,
                refresh: tokens.refresh_token
            )
            lastLoggedInEmail = Self.emailFromJWT(idToken)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
