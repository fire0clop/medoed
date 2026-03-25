// Services/ProfileStorage.swift
import Foundation

final class ProfileStorage {

    private func key(for userId: Int) -> String {
        "cached_profile_\(userId)"
    }

    func save(_ profile: ProfileDTO, userId: Int) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key(for: userId))
        }
    }

    func load(userId: Int) -> ProfileDTO? {
        guard let data = UserDefaults.standard.data(forKey: key(for: userId)) else { return nil }
        return try? JSONDecoder().decode(ProfileDTO.self, from: data)
    }

    func clear(userId: Int) {
        UserDefaults.standard.removeObject(forKey: key(for: userId))
    }
}
