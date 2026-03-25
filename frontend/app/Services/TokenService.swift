// Services/TokenService.swift
import Foundation
import SwiftUI

final class TokenService {

    private let keychain = KeychainService()
    private let api = APIClient.shared

    @AppStorage("access_token") private var accessToken: String?
    
    var userId: Int? {
        guard let token = accessToken else { return nil }
        return extractUserId(from: token)
    }

    var hasRefreshToken: Bool {
        keychain.read(key: "refresh_token") != nil
    }

    /// Для `POST /auth/logout` до очистки Keychain.
    func peekRefreshToken() -> String? {
        keychain.read(key: "refresh_token")
    }

    func saveTokens(access: String, refresh: String) {
        accessToken = access
        keychain.save(refresh, key: "refresh_token")
    }

    func clearTokens() {
        accessToken = nil
        keychain.delete(key: "refresh_token")
    }

    func refreshAccessToken() async throws {
        guard let refresh = keychain.read(key: "refresh_token") else {
            throw APIError.unauthorized
        }

        // retry: false — иначе при 401 от /auth/refresh APIClient снова вызовет refresh → переполнение стека
        let pair: TokenPair = try await api.request(
            "/auth/refresh",
            method: "POST",
            body: ["refresh_token": refresh],
            authorized: false,
            retry: false
        )

        saveTokens(access: pair.access_token, refresh: pair.refresh_token)
    }
    
    // MARK: - JWT Parsing
    
    private func extractUserId(from token: String) -> Int? {
        // Разделяем JWT на части
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        // Декодируем payload (вторая часть)
        let payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Добавляем паддинг для base64
        let paddedLength = payload.count + (4 - payload.count % 4) % 4
        let padded = payload.padding(toLength: paddedLength, withPad: "=", startingAt: 0)
        
        // Декодируем base64
        guard let data = Data(base64Encoded: padded) else { return nil }
        
        // Парсим JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        
        // Пробуем разные возможные названия полей для ID пользователя
        if let userId = json["user_id"] as? Int {
            return userId
        }
        if let userId = json["sub"] as? Int {
            return userId
        }
        if let userId = json["id"] as? Int {
            return userId
        }
        if let userId = json["userId"] as? Int {
            return userId
        }
        if let userId = json["uid"] as? Int {
            return userId
        }
        
        // Пробуем парсить строковые значения
        if let userIdString = json["user_id"] as? String, let userId = Int(userIdString) {
            return userId
        }
        if let userIdString = json["sub"] as? String, let userId = Int(userIdString) {
            return userId
        }
        if let userIdString = json["id"] as? String, let userId = Int(userIdString) {
            return userId
        }
        
        return nil
    }
}
