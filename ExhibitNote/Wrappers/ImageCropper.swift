//
//  ImageCropper.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2025/11/11.
//

import SwiftUI
import CropViewController

struct ImageCropper: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool      // ← sheet制御用
    var onComplete: (UIImage) -> Void   // ← トリミング完了時

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> CropViewController {
        let srcImage = image ?? UIImage()

        let cropVC = CropViewController(image: srcImage)
        cropVC.delegate = context.coordinator

        return cropVC
    }

    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {
        // 今回は特に更新不要
    }

    class Coordinator: NSObject, CropViewControllerDelegate {
        let parent: ImageCropper

        init(_ parent: ImageCropper) {
            self.parent = parent
        }

        // ✅ 決定時：SwiftUIの状態だけ変えて閉じる
        func cropViewController(_ cropViewController: CropViewController,
                                didCropToImage image: UIImage,
                                withRect cropRect: CGRect,
                                angle: Int) {
            parent.onComplete(image)
            parent.isPresented = false
        }

        // ✅ キャンセル時：同じく状態だけ落とす
        func cropViewController(_ cropViewController: CropViewController,
                                didFinishCancelled cancelled: Bool) {
            parent.isPresented = false
        }
    }
}
