import TokenBarCore
import TokenBarMacroSupport
import Foundation

@ProviderImplementationRegistration
struct GrokProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .grok
}
