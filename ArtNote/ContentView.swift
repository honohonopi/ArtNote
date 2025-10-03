//
//  ContentView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            ExhibitionsCalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            ExhibitionsView()
                .tabItem { Label("Exhibitions", systemImage: "calendar") }
        }
    }
}

#Preview {
    ContentView()
}
