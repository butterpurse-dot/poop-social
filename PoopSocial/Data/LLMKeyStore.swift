import Foundation
import Security

/// Stores the user's LLM API key in the **Keychain**.
///
/// Not `UserDefaults`, not a plist, not a file. An API key is a bearer
/// credential: anyone who reads it can spend the user's money. `UserDefaults`
/// is backed by a plaintext plist in the app container, which is included in
/// unencrypted backups — the Keychain is not.
///
/// This is also the reason the key never enters the SwiftData graph: model
/// objects are for content, not secrets.
struct LLMKeyStore {

    static let shared = LLMKeyStore()

    private let service = "com.poopsocial.app.llm"
    private let account = "api-key"

    /// Optional override so tests can use an isolated service name and not
    /// touch the real Keychain entry.
    let serviceName: String

    init(service: String = "com.poopsocial.app.llm") {
        self.serviceName = service
    }

    // MARK: Read / write / delete

    func apiKey() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Save (or replace) the key. An empty string clears it.
    @discardableResult
    func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return clear() }

        let data = Data(trimmed.utf8)
        let query = baseQuery()

        // Replace if present, add if not. Two calls rather than
        // SecItemUpdate-then-SecItemAdd so the common path is one syscall.
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        // The key must not sync to other devices or leave this device.
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func clear() -> Bool {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: Helpers

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]
    }
}
