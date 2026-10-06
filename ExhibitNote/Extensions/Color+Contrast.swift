import SwiftUI
import UIKit

extension Color {
    /// 背景色の明るさに応じて、読みやすい白または黒の文字色を返す。
    var readableForegroundColor: Color {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .white
        }

        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance < 0.6 ? .white : .black
    }
}
