import AppKit
import TokenBarCore

enum ProviderBrandIcon {
    private static let size = NSSize(width: 16, height: 16)

    /// Lazy-loaded resource bundle for provider icons.
    private static let resourceBundle: Bundle? = {
        // SwiftPM creates a TokenBar_TokenBar.bundle for resources in the TokenBar target.
        if let bundleURL = Bundle.main.url(forResource: "TokenBar_TokenBar", withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL)
        {
            return bundle
        }
        // Fallback to main bundle for development/testing.
        return Bundle.main
    }()

    static func image(for provider: UsageProvider) -> NSImage? {
        let baseName = ProviderDescriptorRegistry.descriptor(for: provider).branding.iconResourceName
        guard let bundle = self.resourceBundle,
              let url = bundle.url(forResource: baseName, withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.size = self.size
        image.isTemplate = true
        return image
    }

    // swiftlint:disable cyclomatic_complexity
    /// SF Symbol name to use when the bundled SVG icon cannot be loaded.
    static func fallbackSymbolName(for provider: UsageProvider) -> String {
        switch provider {
        case .codex: "spiral"
        case .claude: "sun.max"
        case .cursor: "cube"
        case .gemini: "diamond"
        case .copilot: "person.2"
        case .openrouter: "arrow.triangle.branch"
        case .windsurf: "sailboat"
        case .deepseek: "magnifyingglass"
        case .codebuff: "terminal"
        case .krill: "fish"
        case .custom: "gearshape.2"
        case .openai: "creditcard"
        case .manus: "brain"
        case .mimo: "m.circle"
        case .doubao: "d.circle"
        case .crof: "c.circle"
        case .venice: "v.circle"
        case .commandcode: "terminal.fill"
        case .stepfun: "s.circle"
        case .antigravity: "arrow.up.and.down.and.sparkles"
        case .zai: "bolt"
        case .minimax: "m.square"
        case .kimi, .kimik2: "k.square"
        case .augment: "plus.square.on.square"
        case .jetbrains: "hammer"
        case .ollama: "lizard"
        case .vertexai: "hexagon"
        case .perplexity: "questionmark.square.dashed"
        case .mistral: "wind"
        case .warp: "terminal"
        case .alibaba: "shippingbox"
        case .abacus: "function"
        case .factory: "gearshape"
        case .opencode: "lock.open"
        case .opencodego: "lock.open.fill"
        case .amp: "waveform"
        case .kiro: "leaf"
        case .kilo: "scalemass"
        case .synthetic: "testtube.2"
        }
    }
    // swiftlint:enable cyclomatic_complexity
}
