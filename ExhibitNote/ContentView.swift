//
//  ContentView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
            ExhibitionsCalendarView()
                .tabItem { Label("カレンダー", systemImage: "calendar") }
            ExhibitionsView()
                .tabItem { Label("展覧会リスト", systemImage: "list.bullet") }
        }
    }
}

#Preview {
    ContentView()
}
