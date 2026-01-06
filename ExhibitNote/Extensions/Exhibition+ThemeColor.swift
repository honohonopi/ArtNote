//
//  Exhibition+ThemeColor.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI
import Foundation
import CoreLocation

extension Exhibition {
    var uiColor: UIColor? {
        guard let r = colorR, let g = colorG, let b = colorB else { return nil }
        return UIColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
    var swiftUIColor: Color? {
        guard let c = uiColor else { return nil }
        return Color(cgColor: c.cgColor)
    }
    
    func setColor(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        colorR = Int16((r * 255).rounded())
        colorG = Int16((g * 255).rounded())
        colorB = Int16((b * 255).rounded())
    }
}
