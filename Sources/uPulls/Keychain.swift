import Foundation
import Security

/// Generic-password storage for the GitHub token. Ad-hoc signed builds get a
/// fresh code identity every compile, so the first read after a rebuild may
/// prompt for keychain access — "Always Allow" makes it go away.
enum Keychain {
    private static let service = "com.upulls.app"
    private static let account = "github-token"

    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read() -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            SecItemDelete(base as CFDictionary)
            return
        }
        let data = Data(trimmed.utf8)
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrLabel as String] = "uPulls GitHub token"
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
