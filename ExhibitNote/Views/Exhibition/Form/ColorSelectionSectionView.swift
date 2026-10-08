import SwiftUI
import UIKit

struct ColorSelectionSectionView: View {
    @Binding var pickedColor: Color?
    @Binding var autoColor: UIColor?

    var body: some View {
        Section("色を選択") {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(pickedColor ?? (autoColor.map { Color($0) } ?? Color.blue))
                    .frame(width: 24, height: 24)

                ColorPicker(
                    "帯の色",
                    selection: Binding(
                        get: { pickedColor ?? (autoColor.map { Color($0) } ?? .blue) },
                        set: { pickedColor = $0 }
                    ),
                    supportsOpacity: false
                )
            }
        }
    }
}

