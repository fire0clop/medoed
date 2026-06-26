// Utils/KeychainService.swift

import Foundation
import Security

final class KeychainService {

    private let service = "DiabetAI"

    func save(_ value: String, key: String) {
        let data = Data(value.utf8)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [CFString: Any] = query.merging([
            kSecValueData: data
        ]) { $1 }

        SecItemAdd(attributes as CFDictionary, nil)
    }

    func read(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard
            status == errSecSuccess,
            let data = result as? Data
        else { return nil }

        return String(decoding: data, as: UTF8.self)
    }

    func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
