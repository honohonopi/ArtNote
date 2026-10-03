import SwiftUI

struct ExhibitionRowView: View {
    let ex: Exhibition
    let distanceKm: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ex.title).font(.headline)
            Text("\(ex.venue)｜〜 \(ex.endDate.ymdString)")
                .font(.subheadline).foregroundStyle(.secondary)
            if let km = distanceKm {
                Text(String(format: "約 %.1f km", km))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
