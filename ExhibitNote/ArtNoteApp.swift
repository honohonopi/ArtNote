//
//  ArtNoteApp.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData

#if canImport(FirebaseCore)
import FirebaseCore
#endif


@main
struct ArtNoteApp: App {
    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.calendar, Calendar.japan)
                .environment(\.timeZone, Calendar.japan.timeZone)
        }
        .modelContainer(for: [Exhibition.self, Reminder.self])
    }
}
