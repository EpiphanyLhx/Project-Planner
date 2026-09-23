import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsStore.apiURLKey) private var apiURL = AIServiceConfiguration.default.apiURL
    @AppStorage(SettingsStore.apiKeyKey) private var apiKey = ""
    @AppStorage(SettingsStore.modelKey) private var model = AIServiceConfiguration.default.model

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section {
                    TextField("API URL", text: $apiURL)
                        .textContentType(.URL)
                    SecureField("API Key", text: $apiKey)
                    TextField("模型名称", text: $model)
                } header: {
                    Text("AI 服务")
                } footer: {
                    Text("支持 OpenAI Chat Completions 兼容接口。可填写基础地址（例如 https://api.deepseek.com），应用会自动补全 /chat/completions。API Key 保存在本机 UserDefaults 中。")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
