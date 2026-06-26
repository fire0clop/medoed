// API/ProfileAPI.swift

import Foundation

final class ProfileAPI {
    private let api = APIClient.shared

    func getProfile() async throws -> ProfileDTO {
        try await api.request("/profile", authorized: true)
    }

    func updateProfile(_ profile: ProfileDTO) async throws -> ProfileDTO {
        try await api.request("/profile", method: "PUT", body: profile, authorized: true)
    }
}
