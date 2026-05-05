import AppKit
import TokenBarCore

enum ProviderBrandIcon {
    private static let size = NSSize(width: 16, height: 16)

    /// Lazy-loaded resource bundle for provider icons.
    private static let resourceBundle: Bundle? = {
        // SwiftPM creates a CodexBar_CodexBar.bundle for resources in the TokenBar target.
        if let bundleURL = Bundle.main.url(forResource: "CodexBar_CodexBar", withExtension: "bundle"),
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

    /// SF Symbol name to use when the bundled SVG icon cannot be loaded.
    static func fallbackSymbolName(for provider: UsageProvider) -> String {
        switch provider {
        case .codex: return "spiral"
        case .claude: return "sun.max"
        case .cursor: return "cube"
        case .gemini: return "diamond"
        case .copilot: return "person.2"
        case .openrouter: return "arrow.triangle.branch"
        case .deepseek: return "magnifyingglass"
        case .krill: return "fish"
        case .custom: return "gearshape.2"
        case .antigravity: return "arrow.up.and.down.and.sparkles"
        case .zai: return "bolt"
        case .minimax: return "m.square"
        case .kimi, .kimik2: return "k.square"
        case .augment: return "plus.square.on.square"
        case .jetbrains: return "hammer"
        case .ollama: return "lizard"
        case .vertexai: return "hexagon"
        case .perplexity: return "questionmark.square.dashed"
        case .mistral: return "wind"
        case .warp: return "terminal"
        case .alibaba: return "shippingbox"
        case .abacus: return "function"
        case .factory: return "gearshape"
        case .opencode: return "lock.open"
        case .opencodego: return "lock.open.fill"
        case .amp: return "waveform"
        case .kiro: return "leaf"
        case .kilo: return "scalemass"
        case .synthetic: return "testtube.2"
        }
    }
}
