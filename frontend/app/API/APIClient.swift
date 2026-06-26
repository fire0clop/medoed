// API/APIClient.swift
import Foundation
import SwiftUI

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(status: Int, message: String)
    case decodingFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .unauthorized:
            return "Необходима авторизация"
        case .httpError(_, let message):
            return message
        case .decodingFailed(let message):
            return "Ошибка формата данных: \(message)"
        }
    }
}

final class APIClient {

    static let shared = APIClient()

    /// Отдельная сессия с таймаутами: иначе при «висящем» DNS/сети bootstrap может не завершаться бесконечно.
    private static let urlSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.timeoutIntervalForResource = 60
        return URLSession(configuration: c)
    }()

    @AppStorage("access_token") private var accessToken: String?

    // MARK: - Public request (декодирует в T)

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authorized: Bool = false,
        retry: Bool = true
    ) async throws -> T {

        let url = Constants.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if authorized, let token = accessToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await Self.urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 && retry {
            let tokenService = TokenService()

            do {
                try await tokenService.refreshAccessToken()

                return try await self.request(
                    path,
                    method: method,
                    body: body,
                    authorized: authorized,
                    retry: false
                )
            } catch {
                throw APIError.unauthorized
            }
        }
        
        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let message = Self.extractDetailMessage(from: data)
                ?? String(data: data, encoding: .utf8)
                ?? "Ошибка сервера (HTTP \(http.statusCode))"

            #if DEBUG
            print("HTTP \(http.statusCode) \(method) \(url.absoluteString)")
            print("Response body:", String(data: data, encoding: .utf8) ?? "<non-utf8>")
            #endif

            throw APIError.httpError(status: http.statusCode, message: message)
        }

        let payload = data.isEmpty ? Data("{}".utf8) : data

        do {
            return try Self.makeDecoder().decode(T.self, from: payload)
        } catch {
            #if DEBUG
            print("DECODING ERROR \(method) \(url.absoluteString)")
            print("Raw body:", String(data: payload, encoding: .utf8) ?? "<non-utf8>")
            #endif
            throw APIError.decodingFailed(message: error.localizedDescription)
        }
    }
    
    // MARK: - Raw request (возвращает Data, без декодирования)

    func rawRequest<T: Encodable>(
        _ path: String,
        method: String = "GET",
        body: T? = nil,
        authorized: Bool = false,
        retry: Bool = true
    ) async throws -> Data {
        let url = Constants.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if authorized, let token = accessToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await Self.urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 && retry {
            let tokenService = TokenService()

            do {
                try await tokenService.refreshAccessToken()

                return try await self.rawRequest(
                    path,
                    method: method,
                    body: body,
                    authorized: authorized,
                    retry: false
                )
            } catch {
                throw APIError.unauthorized
            }
        }
        
        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let message = Self.extractDetailMessage(from: data)
                ?? String(data: data, encoding: .utf8)
                ?? "Ошибка сервера (HTTP \(http.statusCode))"

            #if DEBUG
            print("HTTP \(http.statusCode) \(method) \(url.absoluteString)")
            print("Response body:", String(data: data, encoding: .utf8) ?? "<non-utf8>")
            #endif

            throw APIError.httpError(status: http.statusCode, message: message)
        }

        return data
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        decoder.keyDecodingStrategy = .useDefaultKeys

        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let value = try container.decode(String.self)

            // FastAPI datetime без timezone:
            // 2026-02-11T13:27:13.808203
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"

            if let date = formatter.date(from: value) {
                return date
            }

            // fallback без микросекунд
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(value)"
            )
        }

        return decoder
    }

    // MARK: - Error detail extractor (FastAPI)

    private static func extractDetailMessage(from data: Data) -> String? {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = obj["detail"]
        else { return nil }

        if let s = detail as? String { return s }

        if let arr = detail as? [[String: Any]] {
            if let first = arr.first {
                let msg = (first["msg"] as? String) ?? "Validation error"
                if let loc = first["loc"] as? [Any] {
                    let path = loc.map { "\($0)" }.joined(separator: ".")
                    return "\(path): \(msg)"
                }
                return msg
            }
            return "Validation error"
        }

        return nil
    }
}

// MARK: - AnyEncodable

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
