import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class ExhibitionMemoViewModel {
    var memoData: Data
    var memoPlainText = ""
    var memoAction: MemoAction?

    private let exhibition: Exhibition

    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        memoData = exhibition.memoData ?? Data()
    }

    var numberSuggestions: [String] {
        MemoNumberSuggestionGenerator.suggestions(from: memoPlainText)
    }

    func updatePlainText(_ text: String) {
        memoPlainText = text
    }

    func insertCameraImage(_ image: UIImage) {
        memoAction = .insertImage(image)
    }

    func insertPhoto(from item: PhotosPickerItem?) async {
        guard let item, let image = await item.loadUIImage() else { return }
        memoAction = .insertImage(image)
    }

    func insertNumber(_ value: String) {
        memoAction = .insertText("#\(value) ")
    }

    func insertNumberMarker() {
        memoAction = .insertText("#")
    }

    func insertDivider() {
        memoAction = .insertDivider
    }

    func save(_ data: Data? = nil) {
        let dataToSave = data ?? memoData
        guard exhibition.memoData != dataToSave else { return }
        exhibition.memoData = dataToSave
        exhibition.memoUpdatedAt = .now
    }
}
