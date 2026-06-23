import Foundation
import TokenBarCore

extension SettingsStore {
    var poeAPIKey: String {
        get {
            self.configSnapshot.providerConfig(for: .poe)?.sanitizedAPIKey ?? ""
        }
        set {
            self.updateProviderConfig(provider: .poe) { entry in
                entry.apiKey = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .poe, field: "apiKey", value: newValue)
        }
    }
}
