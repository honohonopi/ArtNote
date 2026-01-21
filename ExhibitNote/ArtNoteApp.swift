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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Exhibition.self, Reminder.self])
    }
}
