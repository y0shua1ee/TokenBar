import TokenBarCore
import TokenBarMacroSupport
import Foundation

@ProviderImplementationRegistration
struct KiroProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .kiro
}
