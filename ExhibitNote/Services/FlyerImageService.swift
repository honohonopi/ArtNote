import PDFKit
import UIKit

/// 読み込んだチラシのPDFや画像を、文字認識に使用する1枚の画像へ変換する。
enum FlyerImageService {
    static func pdfPageCount(at url: URL) -> Int? {
        withSecurityScopedAccess(to: url) {
            PDFDocument(url: url)?.pageCount
        }
    }

    static func image(
        fromPDF url: URL,
        pageIndex: Int,
        maxSide: CGFloat = 2000
    ) -> UIImage? {
        withSecurityScopedAccess(to: url) {
            guard let document = PDFDocument(url: url),
                  pageIndex >= 0,
                  pageIndex < document.pageCount,
                  let page = document.page(at: pageIndex)
            else { return nil }

            return render(page, maxSide: maxSide)
        }
    }

    static func combinedImage(
        fromPDF url: URL,
        pageIndices: [Int],
        maxSide: CGFloat = 1600
    ) -> UIImage? {
        withSecurityScopedAccess(to: url) {
            guard let document = PDFDocument(url: url) else { return nil }

            let images = pageIndices.compactMap { index -> UIImage? in
                guard index >= 0,
                      index < document.pageCount,
                      let page = document.page(at: index)
                else { return nil }

                return render(page, maxSide: maxSide)
            }
            return combineVertically(images)
        }
    }

    static func combineVertically(
        _ images: [UIImage],
        maxWidth: CGFloat = 1600,
        spacing: CGFloat = 12
    ) -> UIImage? {
        guard !images.isEmpty else { return nil }

        let width = min(images.map(\.size.width).max() ?? 0, maxWidth)
        guard width > 0 else { return nil }

        let sizes = images.map { image in
            let scale = width / image.size.width
            return CGSize(width: width, height: image.size.height * scale)
        }
        let totalHeight = sizes.reduce(0) { $0 + $1.height }
            + spacing * CGFloat(max(0, sizes.count - 1))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalHeight))

        return renderer.image { _ in
            var y: CGFloat = 0
            for (index, image) in images.enumerated() {
                let size = sizes[index]
                image.draw(in: CGRect(origin: CGPoint(x: 0, y: y), size: size))
                y += size.height + spacing
            }
        }
    }

    private static func render(_ page: PDFPage, maxSide: CGFloat) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        guard pageRect.width > 0, pageRect.height > 0 else { return nil }

        let scale = min(maxSide / max(pageRect.width, pageRect.height), 1)
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
    }

    private static func withSecurityScopedAccess<Result>(
        to url: URL,
        operation: () -> Result
    ) -> Result {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        return operation()
    }
}
