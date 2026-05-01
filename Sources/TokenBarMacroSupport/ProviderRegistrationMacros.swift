@attached(peer, names: prefixed(_CodexBarDescriptorRegistration_))
public macro ProviderDescriptorRegistration() = #externalMacro(
    module: "TokenBarMacros",
    type: "ProviderDescriptorRegistrationMacro")

@attached(member, names: named(descriptor))
public macro ProviderDescriptorDefinition() = #externalMacro(
    module: "TokenBarMacros",
    type: "ProviderDescriptorDefinitionMacro")

@attached(peer, names: prefixed(_CodexBarImplementationRegistration_))
public macro ProviderImplementationRegistration() = #externalMacro(
    module: "TokenBarMacros",
    type: "ProviderImplementationRegistrationMacro")
