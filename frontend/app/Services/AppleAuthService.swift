// Services/AppleAuthService.swift

import AuthenticationServices
import UIKit

final class AppleAuthService: NSObject {

    private var continuation: CheckedContinuation<String, Error>?
    // Сильная ссылка — без неё контроллер освобождается до вызова делегата
    private var authController: ASAuthorizationController?

    func signIn() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.authController = controller   // удерживаем в памяти
            controller.performRequests()
        }
    }

    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let ordered = scenes.sorted {
            func rank(_ s: UIWindowScene) -> Int {
                switch s.activationState {
                case .foregroundActive: return 0
                case .foregroundInactive: return 1
                case .unattached: return 2
                case .background: return 3
                @unknown default: return 4
                }
            }
            return rank($0) < rank($1)
        }
        for scene in ordered {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                return window
            }
        }
        return nil
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthService: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { authController = nil; continuation = nil }

        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let tokenString = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: NSError(
                domain: "AppleAuthService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось получить identity token от Apple"]
            ))
            return
        }
        continuation?.resume(returning: tokenString)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        defer { authController = nil; continuation = nil }

        // Пользователь отменил — не показываем ошибку
        if let authError = error as? ASAuthorizationError,
           authError.code == .canceled {
            continuation?.resume(throwing: ASAuthorizationError(.canceled))
        } else {
            continuation?.resume(throwing: error)
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return Self.keyWindow() ?? UIWindow()
    }
}
