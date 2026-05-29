import Foundation
import TokenBarCore

extension SettingsStore {
    var openAIAPIKey: String {
        get { self.configSnapshot.providerConfig(for: .openai)?.sanitizedAPIKey ?? "" }
        set {
            self.updateProviderConfig(provider: .openai) { entry in
                entry.apiKey = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .openai, field: "apiKey", value: newValue)
        }
    }

    var openAIAPIProjectID: String {
        get { self.configSnapshot.providerConfig(for: .openai)?.sanitizedWorkspaceID ?? "" }
        set {
            self.updateProviderConfig(provider: .openai) { entry in
                entry.workspaceID = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .openai, field: "projectID", value: newValue)
        }
    }
}
