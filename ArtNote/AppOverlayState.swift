//
//  AppOverlayState.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/28.
//

import SwiftUI

final class AppOverlayState: ObservableObject {
    struct MinimizedNote: Identifiable, Equatable {
        let id = UUID()
        let exhibition: Exhibition
        let currentIndex: Int   // 鑑賞モードの“表示番号” (1,2,3…)
    }

    @Published var minimized: MinimizedNote? = nil      // 右下のフローティング表示用
    @Published var restorePayload: MinimizedNote? = nil // 復元シート用
}
