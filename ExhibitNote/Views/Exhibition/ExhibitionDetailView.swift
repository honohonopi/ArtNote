//
//  ExhibitionDetailView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 展覧会詳細
import SwiftUI
import SwiftData

struct ExhibitionDetailView: View {
    let exhibition: Exhibition
    @Environment(\.modelContext) private var context
    @State private var writeState = ExhibitionWriteState()
    @Environment(\.dismiss) private var dismiss

    @State private var vm: ExhibitionDetailViewModel
    @AppStorage("userAdmissionCategory") private var userAdmissionCategoryRaw = UserTicketCategory.adult.rawValue
    @State private var shareItem: ShareItem?
    @State private var isPreparingShare = false
    @State private var shareErrorMessage: String?
    @State private var showShareFallbackPrompt = false
    @State private var showShareNotice = false
    
    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        _vm = State(initialValue: ExhibitionDetailViewModel(exhibition: exhibition))
    }
    
    var body: some View {
        List {
            ExhibitionDetailMemoSectionView(exhibition: exhibition)
            ExhibitionDetailSummarySectionView(exhibition: exhibition) {
                vm.showMapChoice = true
            }
            ExhibitionDetailDetailsSectionView(vm: vm, userAdmissionCategoryRaw: userAdmissionCategoryRaw)
        }
        
        .exhibitionWriteFeedback(writeState)
        .navigationTitle("詳細")
        .sheet(isPresented: $vm.showPlanner) {
            AddVisitEventSheetView(
                exhibition: exhibition,
                initialStart: vm.visitDate
            )
        }
        .sheet(isPresented: $vm.showEdit) {
            ExhibitionEditView(exhibition: exhibition)
                .presentationDetents([.large]) // 好みで .medium も可
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // 共有
                    Button {
                        showShareNotice = true
                    } label: {
                        Label(isPreparingShare ? "リンク作成中..." : "リンクで共有",
                              systemImage: "link")
                    }
                    .disabled(isPreparingShare)
                    // カレンダーに追加
                    Button {
                        vm.visitDate = min(max(Date(), exhibition.startDate), exhibition.endDate)
                        vm.showPlanner = true
                    } label: {
                        Label("カレンダーに追加", systemImage: "calendar.badge.plus")
                    }
                    // 編集
                    Button {
                        vm.showEdit = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Button {
                        exhibition.visited.toggle()
                        exhibition.visitedAt = exhibition.visited ? Date() : nil
                    } label: {
                        Label(exhibition.visited ? "訪問済みを取り消し" : "訪問済みにする",
                              systemImage: exhibition.visited ? "checkmark.circle" : "checkmark.circle.fill")
                    }
                    Divider()
                    // 削除
                    Button(role: .destructive) {
                        vm.showDeleteConfirm = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: item.items)
        }
        .overlay {
            if isPreparingShare {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("リンクを準備中...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .alert("共有できませんでした", isPresented: Binding(
            get: { shareErrorMessage != nil },
            set: { if !$0 { shareErrorMessage = nil } }
        )) {
            Button("OK") { shareErrorMessage = nil }
        } message: {
            Text(shareErrorMessage ?? "")
        }
        .confirmationDialog(
            "共有リンクの有効期限は7日です",
            isPresented: $showShareNotice,
            titleVisibility: .visible
        ) {
            Button("共有する") { Task { await prepareShare() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("7日を過ぎるとリンクは開けなくなります。")
        }
        .confirmationDialog(
            "共有URLが長すぎるため作成できませんでした。\nタイトル・会場・公式リンクのみ共有しますか？",
            isPresented: $showShareFallbackPrompt,
            titleVisibility: .visible
        ) {
            Button("共有する") { shareFallbackText() }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "本当に削除しますか？",
            isPresented: $vm.showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { deleteExhibition() }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "地図で開く",
            isPresented: $vm.showMapChoice,
            titleVisibility: .visible
        ) {
            if let addr = exhibition.address, !addr.isEmpty {
                Button {
                    vm.openInAppleMaps(address: addr)
                } label: { Text("Appleマップで開く") }
                Button {
                    vm.openInGoogleMaps(address: addr)
                } label: { Text("Googleマップで経路案内") }
            } else if let c = exhibition.coordinate {
                Button {
                    vm.openInAppleMaps(c, name: exhibition.title)
                } label: { Text("Appleマップで開く") }
                Button {
                    vm.openInGoogleMaps(c, name: exhibition.title)
                } label: { Text("Googleマップで経路案内") }
            } else {
                // 最後の砦：会場名で検索 または 位置情報未設定の案内
                Button {
                    vm.openInAppleMaps(address: exhibition.venue)
                } label: { Text("Appleマップで開く") }
                Button {
                    vm.openInGoogleMaps(address: exhibition.venue)
                } label: { Text("Googleマップで経路案内") }
                Button("位置情報が未設定です", role: .cancel) {}
            }
        }
    }

    private func prepareShare() async {
        isPreparingShare = true
        defer { isPreparingShare = false }
        let result = await ExhibitionShareService.makeShareURL(for: exhibition)
        switch result {
        case .success(let url):
            shareItem = ShareItem(items: [url])
        case .failure(let error):
            switch error {
            case .tooLong:
                showShareFallbackPrompt = true
            case .unavailable:
                shareErrorMessage = shareErrorMessageText(error)
            }
        }
    }

    private func shareErrorMessageText(_ error: ExhibitionShareService.ShareError) -> String {
        switch error {
        case .tooLong:
            return "共有URLが長すぎるため作成できませんでした。項目を減らして再試行してください。"
        case .unavailable:
            return "共有URLを作成できませんでした。ネットワーク状態を確認して再試行してください。"
        }
    }

    private func shareFallbackText() {
        var items: [Any] = [exhibition.title, exhibition.venue]
        if let url = exhibition.url?.absoluteString, !url.isEmpty {
            items.append(url)
        }
        shareItem = ShareItem(items: items)
    }
    
    private func deleteExhibition() {
        writeState.run(deleting: true) {
            try ExhibitionPersistenceService(context: context).delete(exhibition)
            dismiss()
        }
    }
    
}
