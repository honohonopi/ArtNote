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
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: ExhibitionDetailViewModel
    @AppStorage("userAdmissionCategory") private var userAdmissionCategoryRaw = UserTicketCategory.adult.rawValue
    
    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        _vm = StateObject(wrappedValue: ExhibitionDetailViewModel(exhibition: exhibition))
    }
    
    var body: some View {
        List {
            ExhibitionDetailMemoSectionView(exhibition: exhibition)
            ExhibitionDetailSummarySectionView(exhibition: exhibition) {
                vm.showMapChoice = true
            }
            ExhibitionDetailDetailsSectionView(vm: vm, userAdmissionCategoryRaw: userAdmissionCategoryRaw)
        }
        
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
                    ShareLink(items: [exhibition.title, exhibition.venue]) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
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
    
    private func deleteExhibition() {
        do {
            // 展覧会本体を削除
            context.delete(exhibition)
            try context.save()
            
            // 画面を閉じる（一覧やカレンダーは @Query 経由で自動更新）
            dismiss()
        } catch {
            // TODO: アラート表示など（必要なら）
            print("Delete failed:", error)
        }
    }
    
}
