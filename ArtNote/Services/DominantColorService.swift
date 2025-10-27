//
//  DominantColorService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/19.
//

// 画像から色を取る
import UIKit
import CoreGraphics

enum DominantColorService {
    static func dominantColor(from image: UIImage) -> UIColor? {
        guard let cgImg = image.cgImage else { return nil }

        // 1) 解析負荷を下げるため縮小
        let targetSize = CGSize(width: 64, height: 64)
        guard let ctx = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(targetSize.width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .low
        ctx.draw(cgImg, in: CGRect(origin: .zero, size: targetSize))
        guard let data = ctx.data else { return nil }

        // 2) 4bit 量子化してヒストグラム作成（0-15 の箱）
        let ptr = data.bindMemory(to: UInt8.self, capacity: Int(targetSize.width * targetSize.height * 4))
        var bins = [Int: Int]() // key = (r<<8)|(g<<4)|b, val = count

        let pixelCount = Int(targetSize.width * targetSize.height)
        for i in 0..<pixelCount {
            let offset = i * 4
            let r8 = ptr[offset]
            let g8 = ptr[offset + 1]
            let b8 = ptr[offset + 2]
            // HSV で低彩度/極端な明暗を弾く
            let (h, s, v) = rgbToHsv(r: r8, g: g8, b: b8)
            if s < 0.15 || v < 0.15 || v > 0.98 { continue } // 白/黒/灰を除外気味に

            let r4 = Int(r8) >> 4
            let g4 = Int(g8) >> 4
            let b4 = Int(b8) >> 4
            let key = (r4 << 8) | (g4 << 4) | b4
            bins[key, default: 0] += 1
        }

        guard let (bestKey, _) = bins.max(by: { $0.value < $1.value }) else {
            // すべて除外された場合は全ピクセルで取り直し（黒/白も許可）
            // （簡易フォールバック）
            var allBins = [Int: Int]()
            for i in 0..<pixelCount {
                let offset = i * 4
                let r4 = Int(ptr[offset]) >> 4
                let g4 = Int(ptr[offset+1]) >> 4
                let b4 = Int(ptr[offset+2]) >> 4
                let key = (r4 << 8) | (g4 << 4) | b4
                allBins[key, default: 0] += 1
            }
            guard let (key, _) = allBins.max(by: { $0.value < $1.value }) else { return nil }
            return colorFromKey(key)
        }
        return colorFromKey(bestKey)
    }

    private static func colorFromKey(_ key: Int) -> UIColor {
        let r4 = (key >> 8) & 0xF
        let g4 = (key >> 4) & 0xF
        let b4 = key & 0xF
        // 4bit → 8bit に伸長（0..15 → 0..255）
        let r = CGFloat(r4) / 15.0
        let g = CGFloat(g4) / 15.0
        let b = CGFloat(b4) / 15.0
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    private static func rgbToHsv(r: UInt8, g: UInt8, b: UInt8) -> (CGFloat, CGFloat, CGFloat) {
        let rf = CGFloat(r)/255.0, gf = CGFloat(g)/255.0, bf = CGFloat(b)/255.0
        let maxV = max(rf, gf, bf), minV = min(rf, gf, bf)
        let d = maxV - minV
        var h: CGFloat = 0
        if d != 0 {
            if maxV == rf { h = (gf - bf)/d + (gf < bf ? 6 : 0) }
            else if maxV == gf { h = (bf - rf)/d + 2 }
            else { h = (rf - gf)/d + 4 }
            h /= 6
        }
        let s = maxV == 0 ? 0 : d / maxV
        let v = maxV
        return (h, s, v)
    }
}
