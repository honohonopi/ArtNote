import SwiftUI

struct ExhibitionDetailDateRulesRow: View {
    let title: String
    let rules: [DateRule]
    let text: (DateRule) -> String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                    Text(text(rule))
                }
            }
        }
    }
}
