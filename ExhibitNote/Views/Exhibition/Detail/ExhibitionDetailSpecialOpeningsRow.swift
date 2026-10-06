import SwiftUI

struct ExhibitionDetailSpecialOpeningsRow: View {
    let title: String
    let openings: [SpecialOpening]
    let text: (SpecialOpening) -> String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(Array(openings.enumerated()), id: \.offset) { index, opening in
                    if index > 0 {
                        Divider()
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(text(opening))
                        if let lastEntryTime = opening.lastEntryTime, !lastEntryTime.isEmpty {
                            Text("最終入場 \(lastEntryTime)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
