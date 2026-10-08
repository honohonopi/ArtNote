import SwiftUI

struct ScheduleSectionView<Content: View>: View {
    let isAIAnalyzing: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Section("開館情報") {
            DisclosureGroup {
                content()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                    Text("開館情報")
                        .foregroundStyle(.primary)
                    Spacer()
                    if isAIAnalyzing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
        }
    }
}
