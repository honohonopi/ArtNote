//
//  ArtworkPhotoPicker.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2025/11/08.
//

// Wrappers/ArtworkPhotoPicker.swift
import SwiftUI
import PhotosUI
import SwiftData
import UIKit

struct ArtworkPhotoPicker: View {
    // SwiftDataの@Modelクラスは@Bindableで双方向バインド
    @Bindable var note: ArtworkNote
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 作品サムネ表示（Data -> UIImage）
            if let data = note.photoThumbData,
               let img  = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("作品写真を追加", systemImage: "camera")
            }
            // iOS 17 形式の onChange（2引数版でもOK）
            .onChange(of: pickerItem) { _, newValue in
                Task {
                    guard
                        let data = try? await newValue?.loadTransferable(type: Data.self),
                        let uiImg = UIImage(data: data),
                        let jpeg  = uiImg.jpegData(compressionQuality: 0.85)
                    else { return }
                    // そのままモデルのDataに格納
                    note.photoThumbData = jpeg
                }
            }
        }
    }
}
