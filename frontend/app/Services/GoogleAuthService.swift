// Services/GoogleAuthService.swift

import Foundation
import GoogleSignIn
import UIKit

final class GoogleAuthService {

    private let clientID =
        "465072547487-bcja4p067aej4b75qu2o5emt9cq1r5qs.apps.googleusercontent.com"

    init() {
        // Глобальная конфигурация Google Sign-In (НОВЫЙ API)
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID
        )
    }

    /// Возвращает Google id_token для отправки на бекенд
    func signIn() async throws -> String {

        guard let rootVC = Self.presentingRootViewController() else {
            throw NSError(
                domain: "GoogleAuthService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось найти окно для входа Google"]
            )
        }

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootVC
        )

        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(
                domain: "GoogleAuthService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Missing Google id_token"]
            )
        }

        return idToken
    }

    /// После системного OAuth сцена может быть `.foregroundInactive` — не ограничиваемся только `.foregroundActive`.
    private static func presentingRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        let ordered = scenes.sorted { a, b in
            func rank(_ s: UIWindowScene) -> Int {
                switch s.activationState {
                case .foregroundActive: return 0
                case .foregroundInactive: return 1
                case .unattached: return 2
                case .background: return 3
                @unknown default: return 4
                }
            }
            return rank(a) < rank(b)
        }

        for scene in ordered {
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
            if let root = window?.rootViewController {
                return root
            }
        }
        return nil
    }
}
