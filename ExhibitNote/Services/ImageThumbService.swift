//
//  ImageThumbService.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2025/11/07.
//

import UIKit

enum ImageThumbService {
    static func makeThumbnail(_ image: UIImage, maxSide: CGFloat = 400) -> Data? {
        let scale = max(image.size.width, image.size.height) / maxSide
        let target = (scale > 1) ? CGSize(width: image.size.width/scale, height: image.size.height/scale) : image.size
        let renderer = UIGraphicsImageRenderer(size: target)
        let thumb = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return thumb.jpegData(compressionQuality: 0.85)
    }
}
