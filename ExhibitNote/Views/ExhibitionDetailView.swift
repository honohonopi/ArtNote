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
    @Query private var notes: [ArtworkNote]
    @AppStorage("userAdmissionCategory") private var userAdmissionCategoryRaw = UserTicketCategory.adult.rawValue
    
    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        _vm = StateObject(wrappedValue: ExhibitionDetailViewModel(exhibition: exhibition))
        let exId = exhibition.id
        _notes = Query(filter: #Predicate<ArtworkNote> { n in n.exhibitionId == exId },
                       sort: [SortDescriptor(\.catalogIndex, order: .forward),
                              SortDescriptor(\.catalogNumber, order: .forward)])
    }
    
    var body: some View {
        List {
            ExhibitionDetailStartSectionView {
                if exhibition.catalogImported {
                    vm.showQuick = true
                } else {
                    vm.showStartChoice = true
                }
            }
            ExhibitionDetailSummarySectionView(exhibition: exhibition) {
                vm.showMapChoice = true
            }
            ExhibitionDetailDetailsSectionView(vm: vm, userAdmissionCategoryRaw: userAdmissionCategoryRaw)
            ExhibitionDetailMemoSectionView(notes: notes)
        }
        
        .navigationTitle("詳細")
        .confirmationDialog("目録を読み込んで開始しますか？", isPresented: $vm.showStartChoice) {
            Button("目録を読み込んで開始する") {
                vm.showCatalogImportSheet = true
            }
            Button("後で読み込む") {
                vm.showQuick = true
            }
        }
        .sheet(isPresented: $vm.showQuick) {
            CardPagingNoteView(exhibition: exhibition)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $vm.showCatalogImportSheet) {
            CatalogImportStartView(exhibition: exhibition) {
                vm.showCatalogImportSheet = false
                vm.showQuick = true
            }
            .presentationDetents([.medium, .large])
        }
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
        // 関連メモを巻き添え削除
        let exId = exhibition.id
        do {
            let fd = FetchDescriptor<ArtworkNote>(
                predicate: #Predicate { $0.exhibitionId == exId }
            )
            let related = try context.fetch(fd)
            related.forEach { context.delete($0) }
            
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

private struct CatalogImportStartView: View {
    @Environment(\.dismiss) private var dismiss
    let exhibition: Exhibition
    let onStart: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section("読み込み方法") {
                    Button {
                        startImport()
                    } label: {
                        Label("画像ライブラリから選ぶ", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        startImport()
                    } label: {
                        Label("カメラで撮る", systemImage: "camera.viewfinder")
                    }
                    Button {
                        startImport()
                    } label: {
                        Label("PDFを選ぶ", systemImage: "doc.richtext")
                    }
                }
                Section {
                    Text("目録読み込みのAI処理は次のステップで実装します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("目録を読み込む")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
    
    private func startImport() {
        exhibition.catalogImported = true
        onStart()
    }
}
