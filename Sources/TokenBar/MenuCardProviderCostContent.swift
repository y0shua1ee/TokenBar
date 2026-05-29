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
                    accessibilityLabel: L("Extra usage spent"))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(self.section.spendLine)
                    .font(.footnote)
                Spacer()
                if let percentLine = self.section.percentLine {
                    Text(percentLine)
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                }
            }
        }
    }
}
