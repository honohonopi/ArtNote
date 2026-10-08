import Observation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

@MainActor
@Observable
final class ExhibitionEditViewModel {
    let draft: ExhibitionDraft

    var localPreviewImage: UIImage?
    var showCamera = false
    var showLibrary = false
    var selectedPhotoItem: PhotosPickerItem?

    private let exhibition: Exhibition

    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        draft = ExhibitionDraft(exhibition: exhibition)
    }

    func save(in context: ModelContext) async throws {
        try await ExhibitionPersistenceService(context: context).update(exhibition) {
            draft.apply(to: exhibition)
        }
    }

    func removePoster() {
        draft.removePoster()
        localPreviewImage = nil
    }

    func handlePickedImage(_ image: UIImage) {
        draft.applyPosterAppearance(from: image)
        localPreviewImage = image
    }

    func handleSelectedPhotoItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { selectedPhotoItem = nil }
        guard let image = await item.loadUIImage() else { return }
        handlePickedImage(image)
    }
}
