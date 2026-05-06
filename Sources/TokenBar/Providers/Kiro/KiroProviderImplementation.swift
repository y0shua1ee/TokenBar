import Foundation
import TokenBarCore
import TokenBarMacroSupport

@ProviderImplementationRegistration
struct KiroProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .kiro
}
