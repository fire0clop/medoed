// Pages/DishesViewModel.swift
import Foundation
import Combine
import SwiftUI

@MainActor
final class DishesViewModel: ObservableObject {

    enum Tab: String, CaseIterable, Identifiable {
        case mine = "Мои"
        case publicAll = "Публичные"
        var id: String { rawValue }
    }

    @Published var tab: Tab = .mine
    @Published var query: String = ""

    @Published var dishes: [DishDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var selected: DishDTO?
    @Published var isLoadingSelected = false

    // busy locks
    @Published var likeBusy: Set<Int> = []
    @Published var favBusy: Set<Int> = []

    private let api = DishesAPI()
    private let tokenService = TokenService()
    
    // Текущий ID пользователя
    private var myUserId: Int? {
        tokenService.userId
    }

    // MARK: - Load

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            dishes = try await listWithRefresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - CRUD

    func create(title: String, isPublic: Bool, ingredients: [IngredientDTO]) async -> Bool {
        do {
            let created = try await createWithRefresh(
                DishCreateRequest(title: title, is_public: isPublic, ingredients: ingredients)
            )
            dishes.insert(created, at: 0)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func update(dishId: Int, title: String, isPublic: Bool, ingredients: [IngredientDTO]) async -> Bool {
        do {
            let updated = try await updateWithRefresh(
                id: dishId,
                DishUpdateRequest(title: title, is_public: isPublic, ingredients: ingredients)
            )
            if let i = dishes.firstIndex(where: { $0.id == dishId }) {
                dishes[i] = updated
            }
            if selected?.id == dishId { selected = updated }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(dishId: Int) async {
        do {
            _ = try await deleteWithRefresh(id: dishId)
            dishes.removeAll { $0.id == dishId }
            if selected?.id == dishId { selected = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Likes / Favorites (public tab)

    func toggleLike(dishId: Int) async {
        guard tab == .publicAll else { return }
        if likeBusy.contains(dishId) { return }

        likeBusy.insert(dishId)
        defer { likeBusy.remove(dishId) }

        let old = dishes.first(where: { $0.id == dishId })
        let wasLiked = old?.isLikedSafe ?? false
        let oldCount = old?.likesCountSafe ?? 0

        updateDish(dishId) { d in
            var x = d
            x.is_liked = !wasLiked
            x.likes_count = max(0, oldCount + (!wasLiked ? 1 : -1))
            return x
        }
        if selected?.id == dishId {
            selected = dishes.first(where: { $0.id == dishId })
        }

        do {
            if wasLiked {
                _ = try await unlikeWithRefresh(id: dishId)
            } else {
                _ = try await likeWithRefresh(id: dishId)
            }
        } catch {
            if let old {
                updateDish(dishId) { _ in old }
                if selected?.id == dishId { selected = old }
            }
            errorMessage = error.localizedDescription
        }
    }

    func toggleFavorite(dishId: Int) async {
        guard tab == .publicAll else { return }
        if favBusy.contains(dishId) { return }

        favBusy.insert(dishId)
        defer { favBusy.remove(dishId) }

        let old = dishes.first(where: { $0.id == dishId })
        let wasFav = old?.isFavoritedSafe ?? false

        updateDish(dishId) { d in
            var x = d
            x.is_favorited = !wasFav
            return x
        }
        if selected?.id == dishId {
            selected = dishes.first(where: { $0.id == dishId })
        }

        do {
            if wasFav {
                _ = try await unfavoriteWithRefresh(id: dishId)
            } else {
                _ = try await favoriteWithRefresh(id: dishId)
            }
        } catch {
            if let old {
                updateDish(dishId) { _ in old }
                if selected?.id == dishId { selected = old }
            }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - UI filtering/sorting

    /// Только блюда текущего пользователя (без фильтра поиска) — для калькулятора.
    var visibleMine: [DishDTO] {
        guard let myId = myUserId else { return [] }
        return dishes.filter { $0.author_user_id == myId }
    }

    var visible: [DishDTO] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var base: [DishDTO]
        switch tab {
        case .publicAll:
            base = dishes.filter { $0.is_public }
            base.sort { a, b in
                if a.isFavoritedSafe != b.isFavoritedSafe {
                    return a.isFavoritedSafe && !b.isFavoritedSafe
                }
                if a.likesCountSafe != b.likesCountSafe {
                    return a.likesCountSafe > b.likesCountSafe
                }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
            
        case .mine:
            // Только блюда, созданные текущим пользователем
            guard let myId = myUserId else { return [] }
            base = dishes.filter { $0.author_user_id == myId }
        }

        if q.isEmpty { return base }
        return base.filter { $0.title.lowercased().contains(q) }
    }

    // MARK: - Права на редактирование/удаление

    func canEditOrDelete(_ dish: DishDTO) -> Bool {
        // Приватные блюда всегда принадлежат текущему пользователю
        if !dish.is_public { return true }
        
        // Для публичных — проверяем авторство
        guard let myId = myUserId else { return false }
        return dish.author_user_id == myId
    }

    // MARK: - Helpers

    private func updateDish(_ id: Int, mutate: (DishDTO) -> DishDTO) {
        guard let i = dishes.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            dishes[i] = mutate(dishes[i])
        }
    }

    // MARK: - Refresh wrappers

    private func listWithRefresh() async throws -> [DishDTO] {
        do { return try await api.list() }
        catch APIError.unauthorized {
            try await tokenService.refreshAccessToken()
            return try await api.list()
        }
    }

    private func getWithRefresh(id: Int) async throws -> DishDTO {
        do { return try await api.get(id: id) }
        catch APIError.unauthorized {
            try await tokenService.refreshAccessToken()
            return try await api.get(id: id)
        }
    }

    private func createWithRefresh(_ body: DishCreateRequest) async throws -> DishDTO {
        do { return try await api.create(body) }
        catch APIError.unauthorized {
            try await tokenService.refreshAccessToken()
            return try await api.create(body)
        }
    }

    private func updateWithRefresh(id: Int, _ body: DishUpdateRequest) async throws -> DishDTO {
        do { return try await api.update(id: id, body: body) }
        catch APIError.unauthorized {
            try await tokenService.refreshAccessToken()
            return try await api.update(id: id, body: body)
        }
    }

    private func deleteWithRefresh(id: Int) async throws -> OkResponse {
        do { return try await api.delete(id: id) }
        catch APIError.unauthorized {
            try await tokenService.refreshAccessToken()
            return try await api.delete(id: id)
        }
    }

    private func likeWithRefresh(id: Int) async throws -> OkResponse {
        do { return try await api.like(id: id) }
        catch APIError.unauthorized {
            try await tokenService.refreshAccessToken()
            return try await api.like(id: id)
        }
    }

    private func unlikeWithRefresh(id: Int) async throws -> OkResponse {
        do { return try await api.unlike(id: id) }
        catch APIError.unauthorized {
            try await tokenService.refreshAccessToken()
            return try await api.unlike(id: id)
        }
    }

    private func favoriteWithRefresh(id: Int) async throws -> OkResponse {
        do { return try await api.favorite(id: id) }
        catch APIError.unauthorized {
            try await tokenService.refreshAccessToken()
            return try await api.favorite(id: id)
        }
    }

    private func unfavoriteWithRefresh(id: Int) async throws -> OkResponse {
        do { return try await api.unfavorite(id: id) }
        catch APIError.unauthorized {
            try await tokenService.refreshAccessToken()
            return try await api.unfavorite(id: id)
        }
    }
}
