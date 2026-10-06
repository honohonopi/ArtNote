import SwiftUI

struct ExhibitionPosterPreviewView: View {
    let data: Data?
    let fallbackColor: Color

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                fallbackColor.opacity(0.15)
                Image(systemName: "photo.on.rectangle")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
