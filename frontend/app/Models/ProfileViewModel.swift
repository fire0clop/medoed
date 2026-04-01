import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var profile: ProfileDTO?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSaving = false
    @Published var saveSuccessToast = false

    private let api = ProfileAPI()
    private let storage = ProfileStorage()
    private let tokenService = TokenService()

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let userId = tokenService.userId else {
            errorMessage = "Нет пользователя"
            return
        }

        // ✅ 1. сначала загружаем кэш
        if let cached = storage.load(userId: userId) {
            profile = cached
        }

        // ✅ 2. потом пробуем сервер
        do {
            let fresh = try await api.getProfile()
            profile = fresh
            storage.save(fresh, userId: userId) // обновляем кэш
        } catch {
            // ❗️ если уже есть кэш — просто молчим
            if profile == nil {
                errorMessage = "Нет интернета"
            }
        }
    }

    // MARK: - Save

    func save(updated: ProfileDTO) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        guard let userId = tokenService.userId else {
            errorMessage = "Нет пользователя"
            return
        }

        do {
            let newProfile = try await api.updateProfile(updated)
            profile = newProfile
            storage.save(newProfile, userId: userId) // обновляем кэш
            saveSuccessToast = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
