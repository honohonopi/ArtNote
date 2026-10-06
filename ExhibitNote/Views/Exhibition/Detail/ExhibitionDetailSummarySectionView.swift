import SwiftUI

struct ExhibitionDetailSummarySectionView: View {
    let exhibition: Exhibition
    let onTapMap: () -> Void

    var body: some View {
        Section {
            HStack(spacing: 8) {
                Text(exhibition.title)
                    .font(.title2).bold()
                if let rawURL = exhibition.url?.absoluteString,
                   let url = rawURL.normalizedWebURL() {
                    Link(destination: url) {
                        Image(systemName: "link")
                            .imageScale(.medium)
                            .foregroundStyle(.blue)
                            .accessibilityLabel("公式サイトを開く")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(exhibition.venue)
                    .font(.subheadline)

                if (exhibition.address?.isEmpty == false) || (exhibition.coordinate != nil) {
                    Button(action: onTapMap) {
                        Image(systemName: "mappin.circle")
                            .imageScale(.medium)
                            .foregroundStyle(.blue)
                            .accessibilityLabel("地図アプリで開く")
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "mappin.slash.circle")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            Text("\(exhibition.startDate.ymdString) 〜 \(exhibition.endDate.ymdString)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        } header: {
            Text("概要")
        }
    }
}

