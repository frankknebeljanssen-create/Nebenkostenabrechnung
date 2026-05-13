import Foundation

enum NKConfig {
    /// API-Key wird aus der Keychain gelesen, NICHT hardcodiert.
    static var claudeAPIKey: String {
        KeychainService.getAPIKey() ?? ""
    }

    static let claudeModel = "claude-sonnet-4-20250514"
    static let claudeBaseURL = "https://api.anthropic.com/v1/messages"
    static let anthropicVersion = "2023-06-01"
}
