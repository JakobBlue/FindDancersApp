//
//  EVAPICredentials.swift
//  FindDancers
//
//  Speicherung der HTTP-Basic-Zugangsdaten für die EV-API.
//

import Foundation
import Security

nonisolated struct EVAPICredentials: Codable, Equatable, Sendable {
    var username: String
    var password: String

    /// Wert für den `Authorization`-Header (HTTP Basic, siehe `securitySchemes` in api_docs.json).
    var basicAuthHeaderValue: String {
        let raw = "\(username):\(password)"
        let encoded = Data(raw.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }
}

/// Minimaler Keychain-Wrapper. Das Passwort wird für HTTP Basic bei jeder
/// Anfrage erneut gebraucht und darf deshalb nicht in `session.json` landen.
nonisolated enum EVCredentialStore {
    private static let service = "de.wdw.ev.FindDancers.basic-auth"
    private static let account = "current-user"

    static func save(_ credentials: EVAPICredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load() -> EVAPICredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(EVAPICredentials.self, from: data)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
