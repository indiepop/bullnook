import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var provider: LLMProvider = .deepSeek
    var apiKey: String = ""
    var customBaseURL: String = ""
    var customModel: String = ""
    var isConfigured: Bool = false
    var showSavedConfirmation: Bool = false

    init() {
        loadConfig()
    }

    func loadConfig() {
        guard let config = KeychainManager.load() else {
            isConfigured = false
            return
        }
        provider = LLMProvider(rawValue: config.provider) ?? .deepSeek
        apiKey = config.apiKey
        customBaseURL = config.customBaseURL ?? ""
        customModel = config.customModel ?? ""
        isConfigured = !apiKey.isEmpty
    }

    func saveConfig() {
        let config = LLMConfig(
            provider: provider.rawValue,
            apiKey: apiKey,
            customBaseURL: provider == .custom ? customBaseURL : nil,
            customModel: provider == .custom ? customModel : nil
        )
        do {
            try KeychainManager.save(config: config)
            isConfigured = !apiKey.isEmpty
            showSavedConfirmation = true
        } catch {
            print("Failed to save LLM config: \(error)")
        }
    }

    func clearConfig() {
        KeychainManager.delete()
        apiKey = ""
        customBaseURL = ""
        customModel = ""
        isConfigured = false
    }
}
