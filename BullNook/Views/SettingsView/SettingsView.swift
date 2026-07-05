import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("LLM 服务商") {
                    Picker("服务商", selection: Bindable(viewModel).provider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if viewModel.provider == .custom {
                    Section("自定义接口") {
                        TextField("Base URL", text: Bindable(viewModel).customBaseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Model 名称", text: Bindable(viewModel).customModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("API Key") {
                    SecureField("输入 API Key", text: Bindable(viewModel).apiKey)
                        .textContentType(.password)

                    Button("保存") {
                        viewModel.saveConfig()
                    }
                    .disabled(viewModel.apiKey.isEmpty || (viewModel.provider == .custom && (viewModel.customBaseURL.isEmpty || viewModel.customModel.isEmpty)))

                    if viewModel.isConfigured {
                        Button("清除配置", role: .destructive) {
                            viewModel.clearConfig()
                        }
                    }
                }

                Section("说明") {
                    Text("API Key 仅保存在设备钥匙串中，不会上传到任何服务器。未配置时推荐功能将使用规则摘要替代智能分析。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .alert("已保存", isPresented: Bindable(viewModel).showSavedConfirmation) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("LLM API Key 已保存到钥匙串。")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
}
