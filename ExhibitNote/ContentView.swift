//
//  ContentView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var incomingPayload: ExhibitionSharePayload?
    @State private var shareOpenErrorMessage: String?

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
            ExhibitionsCalendarView()
                .tabItem { Label("カレンダー", systemImage: "calendar") }
            ExhibitionsView()
                .tabItem { Label("展覧会リスト", systemImage: "list.bullet") }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            handleIncomingURL(url)
        }
        .sheet(item: $incomingPayload) { payload in
            ExhibitionImportSheetView(payload: payload) {
                incomingPayload = nil
            }
        }
        .alert("共有リンクを開けませんでした", isPresented: Binding(
            get: { shareOpenErrorMessage != nil },
            set: { if !$0 { shareOpenErrorMessage = nil } }
        )) {
            Button("OK") { shareOpenErrorMessage = nil }
        } message: {
            Text(shareOpenErrorMessage ?? "")
        }
    }

    private func handleIncomingURL(_ url: URL) {
        Task {
            if let payload = await ExhibitionShareService.resolvePayload(from: url) {
                await MainActor.run {
                    incomingPayload = payload
                }
            } else {
                await MainActor.run {
                    shareOpenErrorMessage = shareOpenErrorMessageText(for: url)
                }
            }
        }
    }

    private func shareOpenErrorMessageText(for url: URL) -> String {
        if url.isFileURL {
            return "共有ファイルを読み込めませんでした。"
        }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems
        else {
            return "共有リンクが無効です。"
        }
        if items.contains(where: { $0.name == "id" }) {
            return "共有内容を取得できませんでした。ネットワーク接続を確認してください。"
        }
        if items.contains(where: { $0.name == "data" }) {
            return "共有データを読み込めませんでした。リンクが壊れている可能性があります。"
        }
        return "共有リンクが無効です。"
    }
}

#Preview {
    ContentView()
}
