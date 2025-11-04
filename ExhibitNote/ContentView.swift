//
//  ContentView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var overlay = AppOverlayState()
    @State private var topInset: CGFloat = 0
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
            ExhibitionsCalendarView()
                .tabItem { Label("カレンダー", systemImage: "calendar") }
            ExhibitionsView()
                .tabItem { Label("展覧会リスト", systemImage: "list.bullet") }
        }
        // 画面の safeAreaInsets.top を取得（初回/回転時に更新）
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { topInset = proxy.safeAreaInsets.top }
                    .onChange(of: proxy.safeAreaInsets.top) { topInset = $0 }
            }
        )
        .overlay(alignment: .topTrailing) {
            if let mini = overlay.minimized {
                FloatingNoteWidget(mini: mini)
                    .padding(.trailing, 16)
                    .padding(.top, topInset/2)
                    .environmentObject(overlay)
            }
        }
        // 復元シート
        .sheet(item: $overlay.restorePayload) { payload in
            CardPagingNoteView(exhibition: payload.exhibition, startIndex: payload.currentIndex)
                .environmentObject(overlay)
        }
        .environmentObject(overlay)
    }
}

#Preview {
    ContentView()
}
