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
    var testStatus: LLMTestStatus?
    var isTestingConnection: Bool = false

    init() {
        loadConfig()
    }

    func loadConfig() {
        guard let config = KeychainManager.load() else {
            isConfigured = false
            return
        }
        let savedProvider = LLMProvider(rawValue: config.provider)
        // Migrate removed providers (OpenAI / Claude) to DeepSeek
        if let savedProvider, LLMProvider.allCases.contains(where: { $0 == savedProvider }) {
            provider = savedProvider
        } else {
            provider = .deepSeek
        }
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
            testStatus = nil
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
        testStatus = nil
    }

    func testConnection() async {
        guard !apiKey.isEmpty else {
            testStatus = .failure("请先输入 API Key")
            return
        }

        isTestingConnection = true
        defer { isTestingConnection = false }

        let config = LLMConfig(
            provider: provider.rawValue,
            apiKey: apiKey,
            customBaseURL: provider == .custom ? customBaseURL : nil,
            customModel: provider == .custom ? customModel : nil
        )
        let result = await LLMAnalyzer().testConnection(config: config)
        testStatus = result.success ? .success(result.message) : .failure(result.message)
    }
}

enum LLMTestStatus: Equatable {
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .success(let msg), .failure(let msg):
            return msg
        }
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
