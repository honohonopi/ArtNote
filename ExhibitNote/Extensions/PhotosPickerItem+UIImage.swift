import PhotosUI
import SwiftUI
import UIKit

extension PhotosPickerItem {
    /// 選択した写真のデータを読み込み、UIImageへ変換する。
    func loadUIImage() async -> UIImage? {
        guard let data = try? await loadTransferable(type: Data.self) else { return nil }
        return UIImage(data: data)
    }
}
