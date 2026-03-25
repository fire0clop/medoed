// Models/DishDTO.swift
import Foundation

struct IngredientDTO: Codable, Hashable {
    var name: String
    var weight_g: Double
    var carbs_per_100g: Double

    var carbsTotal: Double {
        (weight_g * carbs_per_100g / 100.0)
    }
}

struct DishDTO: Codable, Identifiable, Hashable {
    let id: Int
    let author_user_id: Int

    var title: String
    var is_public: Bool
    var ingredients: [IngredientDTO]
    let created_at: Date

    // ✅ Значения по умолчанию — теперь декодер НЕ требует эти поля в JSON!
    var likes_count: Int? = 0
    var is_liked: Bool? = false
    var is_favorited: Bool? = false

    var totalCarbs: Double {
        ingredients.reduce(0) { $0 + $1.carbsTotal }
    }

    var totalWeight: Double {
        ingredients.reduce(0) { $0 + $1.weight_g }
    }

    var likesCountSafe: Int { likes_count ?? 0 }
    var isLikedSafe: Bool { is_liked ?? false }
    var isFavoritedSafe: Bool { is_favorited ?? false }
}

// Requests
struct DishCreateRequest: Codable {
    var title: String
    var is_public: Bool
    var ingredients: [IngredientDTO]
}

struct DishUpdateRequest: Codable {
    var title: String
    var is_public: Bool
    var ingredients: [IngredientDTO]
}
