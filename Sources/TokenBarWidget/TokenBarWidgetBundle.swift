import SwiftUI
import WidgetKit

@main
struct TokenBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        TokenBarSwitcherWidget()
        TokenBarUsageWidget()
        TokenBarHistoryWidget()
        TokenBarCompactWidget()
    }
}

struct TokenBarSwitcherWidget: Widget {
    private let kind = "TokenBarSwitcherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: TokenBarSwitcherTimelineProvider())
        { entry in
            TokenBarSwitcherWidgetView(entry: entry)
        }
        .configurationDisplayName("TokenBar Switcher")
        .description("Usage widget with a provider switcher.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TokenBarUsageWidget: Widget {
    private let kind = "TokenBarUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: TokenBarTimelineProvider())
        { entry in
            TokenBarUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("TokenBar Usage")
        .description("Session and weekly usage with credits and costs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TokenBarHistoryWidget: Widget {
    private let kind = "TokenBarHistoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: TokenBarTimelineProvider())
        { entry in
            TokenBarHistoryWidgetView(entry: entry)
        }
        .configurationDisplayName("TokenBar History")
        .description("Usage history chart with recent totals.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct TokenBarCompactWidget: Widget {
    private let kind = "TokenBarCompactWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: CompactMetricSelectionIntent.self,
            provider: TokenBarCompactTimelineProvider())
        { entry in
            TokenBarCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("TokenBar Metric")
        .description("Compact widget for credits or cost.")
        .supportedFamilies([.systemSmall])
    }
}
