import SwiftUI

struct ProviderCostContent: View {
    let section: UsageMenuCardView.Model.ProviderCostSection
    let progressColor: Color
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(self.section.title)
                .font(.body)
                .fontWeight(.medium)
            if let percentUsed = self.section.percentUsed {
                UsageProgressBar(
                    percent: percentUsed,
                    tint: self.progressColor,
                    accessibilityLabel: "Extra usage spent")
                HStack(alignment: .firstTextBaseline) {
                    Text(self.section.spendLine)
                        .font(.footnote)
                    Spacer()
                    Text(String(format: "%.0f%% used", min(100, max(0, percentUsed))))
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                }
            } else {
                Text(self.section.spendLine)
                    .font(.footnote)
            }
        }
    }
}
