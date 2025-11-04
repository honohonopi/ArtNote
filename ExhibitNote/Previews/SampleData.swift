//
//  SampleData.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData

struct PreviewContainer: ViewModifier {
    func body(content: Content) -> some View {
        content
            .modelContainer(for: [Exhibition.self, ArtworkNote.self, Reminder.self], inMemory: true)
            .task { seed() }
    }
    private func seed() {
        // シードは必要ならここに
    }
}

extension View { func withPreviewData() -> some View { modifier(PreviewContainer()) } }


#Preview {
    ContentView().withPreviewData()
}
