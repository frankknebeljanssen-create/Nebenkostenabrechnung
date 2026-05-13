import Foundation
import Security

enum KeychainService {

    private static let serviceName = "com.nkpruefer.api"
    private static let apiKeyAccount = "anthropic_api_key"

    /// Speichert den API-Key sicher in der iOS Keychain.
    @discardableResult
    static func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        // Erst löschen falls schon vorhanden
        deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Liest den API-Key aus der Keychain.
    static func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else { return nil }
        return key
    }

    /// Löscht den API-Key aus der Keychain.
    @discardableResult
    static func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: apiKeyAccount
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    /// Prüft ob ein API-Key gespeichert ist.
    static var hasAPIKey: Bool {
        getAPIKey() != nil
    }
}
