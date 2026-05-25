import Foundation
import TokenBarCore
import TokenBarMacroSupport

@ProviderImplementationRegistration
struct GrokProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .grok
}
