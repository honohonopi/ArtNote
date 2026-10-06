import SwiftUI

struct ExhibitionDetailMemoSectionView: View {
    let exhibition: Exhibition

    var body: some View {
        Section {
            NavigationLink {
                ExhibitionMemoView(exhibition: exhibition)
            } label: {
                Label("鑑賞メモを開く", systemImage: "square.and.pencil")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

