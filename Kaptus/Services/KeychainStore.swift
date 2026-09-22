import Foundation
import Security
import KaptusCore

enum KeychainStore {
    private static let service = "com.desigrit.kaptus.opensubtitles"
    static func load() throws -> ProviderCredentials {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "provider", kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return .init() }
        guard status == errSecSuccess, let data = item as? Data else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        return try JSONDecoder().decode(ProviderCredentials.self, from: data)
    }
    static func save(_ credentials: ProviderCredentials) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "provider"]
        let values: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(credentials), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let updated = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if updated == errSecItemNotFound {
            let status = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil)
            guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        } else if updated != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(updated)) }
    }
}
