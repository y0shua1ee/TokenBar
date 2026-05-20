import Foundation
import TokenBarCore

extension SettingsStore {
    var openRouterAPIToken: String {
        get { self.configSnapshot.providerConfig(for: .openrouter)?.sanitizedAPIKey ?? "" }
        set {
            self.updateProviderConfig(provider: .openrouter) { entry in
                entry.apiKey = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .openrouter, field: "apiKey", value: newValue)
        }
    }

    var openRouterManagementAPIKey: String {
        get { self.configSnapshot.providerConfig(for: .openrouter)?.sanitizedManagementAPIKey ?? "" }
        set {
            self.updateProviderConfig(provider: .openrouter) { entry in
                entry.managementAPIKey = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .openrouter, field: "managementAPIKey", value: newValue)
        }
    }
}
