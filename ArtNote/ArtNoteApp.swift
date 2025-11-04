//
//  ArtNoteApp.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData


@main
struct ArtNoteApp: App {
    @StateObject private var overlay = AppOverlayState()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(overlay)
        }
        .modelContainer(for: [Exhibition.self, ArtworkNote.self, Reminder.self])
    }
}
