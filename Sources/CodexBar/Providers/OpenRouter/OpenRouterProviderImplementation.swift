import AppKit
import CodexBarCore
import Foundation
import SwiftUI

struct OpenRouterProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .openrouter

    @MainActor
    func presentation(context _: ProviderPresentationContext) -> ProviderPresentation {
        ProviderPresentation { context in
            context.store.sourceLabel(for: context.provider)
        }
    }

    @MainActor
    func observeSettings(_ settings: SettingsStore) {
        _ = settings[providerConfig: .openrouter, field: .apiKey]
        _ = settings[providerConfig: .openrouter, field: .secretKey]
        _ = settings[providerConfig: .openrouter, field: .endpoint]
    }

    @MainActor
    func isAvailable(context: ProviderAvailabilityContext) -> Bool {
        if OpenRouterSettingsReader.apiToken(environment: context.environment) != nil ||
            OpenRouterSettingsReader.managementKey(environment: context.environment) != nil
        {
            return true
        }
        let apiKey = context.settings[providerConfig: .openrouter, field: .apiKey]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let managementKey = context.settings[providerConfig: .openrouter, field: .secretKey]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !apiKey.isEmpty || !managementKey.isEmpty
    }

    @MainActor
    func settingsPickers(context _: ProviderSettingsContext) -> [ProviderSettingsPickerDescriptor] {
        []
    }

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "openrouter-api-key",
                title: "API key",
                subtitle: "Stored in \(TokenBarIdentity.configPathHint). TokenBar uses this regular API key for "
                    + "Credits balance and current-key quota. Set its spending limit at openrouter.ai/settings/keys "
                    + "to enable quota tracking.",
                kind: .secure,
                placeholder: "sk-or-v1-...",
                binding: context.providerConfigBinding(.apiKey),
                actions: [],
                isVisible: nil,
                onActivate: nil),
            ProviderSettingsFieldDescriptor(
                id: "openrouter-management-key",
                title: "Management key (Activity)",
                subtitle: "Stored in \(TokenBarIdentity.configPathHint). Account-level Activity only: the last 30 "
                    + "completed UTC days. Management keys cannot be used for completions, and TokenBar does not "
                    + "use this key for Credits balance or current-key quota.",
                kind: .secure,
                placeholder: "OpenRouter management key…",
                binding: context.providerConfigBinding(.secretKey),
                actions: [
                    ProviderSettingsActionDescriptor(
                        id: "openrouter-open-management-keys",
                        title: "Open Management Keys",
                        style: .link,
                        isVisible: nil,
                        perform: {
                            if let url = URL(string: "https://openrouter.ai/settings/management-keys") {
                                NSWorkspace.shared.open(url)
                            }
                        }),
                ],
                isVisible: nil,
                onActivate: nil),
            ProviderSettingsFieldDescriptor(
                id: "openrouter-api-url",
                title: "API URL",
                subtitle: "Optional override for regular-key Credits balance and quota. Management Activity "
                    + "always uses OpenRouter's hosted API.",
                kind: .plain,
                placeholder: "https://openrouter.ai/api/v1",
                binding: context.providerConfigBinding(.endpoint),
                actions: [],
                isVisible: nil,
                onActivate: nil),
        ]
    }
}
