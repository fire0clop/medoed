// Services/DishesAPI.swift
import Foundation

// Пустая структура для запросов без тела
private struct EmptyBody: Encodable {}

final class DishesAPI {
    private let api = APIClient.shared
    
    // Специальный декодер для DishDTO, который не падает без полей
    private func decodeDish(from data: Data) throws -> DishDTO {
        // Сначала пробуем стандартную декодировку
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let value = try container.decode(String.self)
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            
            if let date = formatter.date(from: value) {
                return date
            }
            
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = formatter.date(from: value) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(value)"
            )
        }
        
        do {
            return try decoder.decode(DishDTO.self, from: data)
        } catch {
            // Если не получилось — парсим вручную и добавляем поля по умолчанию
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            guard let id = json["id"] as? Int,
                  let author_user_id = json["author_user_id"] as? Int,
                  let title = json["title"] as? String,
                  let is_public = json["is_public"] as? Bool,
                  let createdAtString = json["created_at"] as? String else {
                throw APIError.decodingFailed(message: "Missing required fields")
            }
            
            let created_at = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
            
            let ingredients: [IngredientDTO] = (json["ingredients"] as? [[String: Any]])?.compactMap { dict in
                guard let name = dict["name"] as? String,
                      let weight = dict["weight_g"] as? Double,
                      let carbs = dict["carbs_per_100g"] as? Double else {
                    return nil
                }
                return IngredientDTO(name: name, weight_g: weight, carbs_per_100g: carbs)
            } ?? []
            
            return DishDTO(
                id: id,
                author_user_id: author_user_id,
                title: title,
                is_public: is_public,
                ingredients: ingredients,
                created_at: created_at,
                likes_count: 0,
                is_liked: false,
                is_favorited: false
            )
        }
    }
    
    private func decodeDishArray(from data: Data) throws -> [DishDTO] {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { dec in
                let container = try dec.singleValueContainer()
                let value = try container.decode(String.self)
                
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                
                if let date = formatter.date(from: value) {
                    return date
                }
                
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                if let date = formatter.date(from: value) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date format: \(value)"
                )
            }
            return try decoder.decode([DishDTO].self, from: data)
        } catch {
            // Если массив не декодируется, пробуем каждый элемент отдельно
            let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            var result: [DishDTO] = []
            
            for json in array {
                guard let id = json["id"] as? Int,
                      let author_user_id = json["author_user_id"] as? Int,
                      let title = json["title"] as? String,
                      let is_public = json["is_public"] as? Bool,
                      let createdAtString = json["created_at"] as? String else {
                    continue
                }
                
                let created_at = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
                
                let ingredients: [IngredientDTO] = (json["ingredients"] as? [[String: Any]])?.compactMap { dict in
                    guard let name = dict["name"] as? String,
                          let weight = dict["weight_g"] as? Double,
                          let carbs = dict["carbs_per_100g"] as? Double else {
                        return nil
                    }
                    return IngredientDTO(name: name, weight_g: weight, carbs_per_100g: carbs)
                } ?? []
                
                result.append(DishDTO(
                    id: id,
                    author_user_id: author_user_id,
                    title: title,
                    is_public: is_public,
                    ingredients: ingredients,
                    created_at: created_at,
                    likes_count: 0,
                    is_liked: false,
                    is_favorited: false
                ))
            }
            
            return result
        }
    }

    func list() async throws -> [DishDTO] {
        let data = try await api.rawRequest("/dishes", method: "GET", body: EmptyBody?.none, authorized: true)
        return try decodeDishArray(from: data)
    }

    func get(id: Int) async throws -> DishDTO {
        let data = try await api.rawRequest("/dishes/\(id)", method: "GET", body: EmptyBody?.none, authorized: true)
        return try decodeDish(from: data)
    }

    func create(_ body: DishCreateRequest) async throws -> DishDTO {
        let data = try await api.rawRequest("/dishes", method: "POST", body: body, authorized: true)
        return try decodeDish(from: data)
    }

    func update(id: Int, body: DishUpdateRequest) async throws -> DishDTO {
        let data = try await api.rawRequest("/dishes/\(id)", method: "PUT", body: body, authorized: true)
        return try decodeDish(from: data)
    }

    func delete(id: Int) async throws -> OkResponse {
        try await api.request("/dishes/\(id)", method: "DELETE", authorized: true)
    }

    func like(id: Int) async throws -> OkResponse {
        try await api.request("/dishes/\(id)/like", method: "POST", authorized: true)
    }

    func unlike(id: Int) async throws -> OkResponse {
        try await api.request("/dishes/\(id)/like", method: "DELETE", authorized: true)
    }

    func favorite(id: Int) async throws -> OkResponse {
        try await api.request("/dishes/\(id)/favorite", method: "POST", authorized: true)
    }

    func unfavorite(id: Int) async throws -> OkResponse {
        try await api.request("/dishes/\(id)/favorite", method: "DELETE", authorized: true)
    }
}

struct OkResponse: Decodable {
    let ok: Bool
}
