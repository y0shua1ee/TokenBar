import AppKit
import Foundation
import SwiftUI
import TokenBarCore

struct OpenRouterProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .openrouter
    let supportsLoginFlow: Bool = true

    @MainActor
    func presentation(context _: ProviderPresentationContext) -> ProviderPresentation {
        ProviderPresentation { _ in "api" }
    }

    @MainActor
    func observeSettings(_ settings: SettingsStore) {
        _ = settings.openRouterAPIToken
        _ = settings.openRouterManagementAPIKey
    }

    @MainActor
    func settingsSnapshot(context: ProviderSettingsSnapshotContext) -> ProviderSettingsSnapshotContribution? {
        _ = context
        return nil
    }

    @MainActor
    func isAvailable(context: ProviderAvailabilityContext) -> Bool {
        if OpenRouterSettingsReader.apiToken(environment: context.environment) != nil {
            return true
        }
        if OpenRouterSettingsReader.activityAPIKey(environment: context.environment) != nil {
            return true
        }
        if !context.settings.openRouterManagementAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return !context.settings.openRouterAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                subtitle: "Stored in ~/.tokenbar/config.json. "
                    + "Optional when Management API key is set; add a spending limit "
                    + "to show current-key quota tracking.",
                kind: .secure,
                placeholder: "sk-or-v1-...",
                binding: context.stringBinding(\.openRouterAPIToken),
                actions: [Self.openKeysAction(id: "openrouter-open-api-keys")],
                isVisible: nil,
                onActivate: nil),
            ProviderSettingsFieldDescriptor(
                id: "openrouter-management-api-key",
                title: "Management API key",
                subtitle: "Used for OpenRouter Activity cost history across the account; "
                    + "also powers balance when API key is empty. Environment: OPENROUTER_MANAGEMENT_KEY.",
                kind: .secure,
                placeholder: "sk-or-v1-...",
                binding: context.stringBinding(\.openRouterManagementAPIKey),
                actions: [Self.openKeysAction(id: "openrouter-open-management-keys")],
                isVisible: nil,
                onActivate: nil),
        ]
    }

    @MainActor
    func loginMenuAction(context _: ProviderMenuLoginContext)
        -> (label: String, action: MenuDescriptor.MenuAction)?
    {
        ("OpenRouter Keys...", .loginToProvider(url: "https://openrouter.ai/settings/keys"))
    }

    @MainActor
    func runLoginFlow(context _: ProviderLoginContext) async -> Bool {
        if let url = URL(string: "https://openrouter.ai/settings/keys") {
            NSWorkspace.shared.open(url)
        }
        return false
    }

    @MainActor
    private static func openKeysAction(id: String) -> ProviderSettingsActionDescriptor {
        ProviderSettingsActionDescriptor(
            id: id,
            title: "Open keys",
            style: .link,
            isVisible: nil,
            perform: {
                if let url = URL(string: "https://openrouter.ai/settings/keys") {
                    NSWorkspace.shared.open(url)
                }
            })
    }
}
