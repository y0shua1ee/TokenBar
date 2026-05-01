import TokenBarCore
import Foundation

/// Minimal provider implementation for custom/generic providers.
/// All behavior comes from the ProviderDescriptor defaults.
struct CustomProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .custom
}
