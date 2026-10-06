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
                        vm.showShareNotice = true
                    } label: {
                        Label(vm.isPreparingShare ? "リンク作成中..." : "リンクで共有",
                              systemImage: "link")
                    }
                    .disabled(vm.isPreparingShare)
                    // カレンダーに追加
                    Button(action: vm.preparePlanner) {
                        Label("カレンダーに追加", systemImage: "calendar.badge.plus")
                    }
                    // 編集
                    Button {
                        vm.showEdit = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Button(action: vm.toggleVisited) {
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
        .sheet(item: $vm.shareItem) { item in
            ShareSheet(items: item.items)
        }
        .overlay {
            if vm.isPreparingShare {
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
            get: { vm.shareErrorMessage != nil },
            set: { if !$0 { vm.shareErrorMessage = nil } }
        )) {
            Button("OK") { vm.shareErrorMessage = nil }
        } message: {
            Text(vm.shareErrorMessage ?? "")
        }
        .confirmationDialog(
            "共有リンクの有効期限は7日です",
            isPresented: $vm.showShareNotice,
            titleVisibility: .visible
        ) {
            Button("共有する") { Task { await vm.prepareShare() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("7日を過ぎるとリンクは開けなくなります。")
        }
        .confirmationDialog(
            "共有URLが長すぎるため作成できませんでした。\nタイトル・会場・公式リンクのみ共有しますか？",
            isPresented: $vm.showShareFallbackPrompt,
            titleVisibility: .visible
        ) {
            Button("共有する", action: vm.prepareFallbackShare)
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "本当に削除しますか？",
            isPresented: $vm.showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                writeState.run(deleting: true) {
                    try vm.delete(in: context)
                    dismiss()
                }
            }
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

}
