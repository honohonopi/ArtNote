//
//  ExhibitionDetailView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 展覧会詳細
import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct ExhibitionDetailView: View {
    let exhibition: Exhibition
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDeleteConfirm = false
    @State private var showEdit = false
    
    @State private var pickedColor: Color = .blue
    
    @Query private var notes: [ArtworkNote]
    @State private var showQuick = false
    @State private var showStartChoice = false
    @State private var showCatalogImportSheet = false
    
    @State private var showPlanner = false
    @State private var visitDate = Date()
    @State private var showAddDone = false
    
    @State private var showMapChoice = false
    @State private var ocrPickedImage: UIImage?
    @State private var showAdmissionDetails = false
    @AppStorage("userAdmissionCategory") private var userAdmissionCategoryRaw = UserAdmissionCategory.adult.rawValue
    
    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        let exId = exhibition.id
        _notes = Query(filter: #Predicate<ArtworkNote> { n in n.exhibitionId == exId },
                       sort: [SortDescriptor(\.catalogIndex, order: .forward),
                              SortDescriptor(\.catalogNumber, order: .forward)])
    }
    
    private func encoded(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }

    // Appleマップ：住所で開く（経路）
    private func openInAppleMaps(address: String) {
        // 経路指定（出発地は現在地）
        let url = URL(string: "http://maps.apple.com/?daddr=\(encoded(address))")!
        UIApplication.shared.open(url)
    }

    // Googleマップ：住所で経路案内（アプリ→無ければWeb）
    private func openInGoogleMaps(address: String) {
        let scheme = "comgooglemaps://?daddr=\(encoded(address))&directionsmode=driving"
        if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Web フォールバック（Google公式の Directions URL）
            let web = "https://www.google.com/maps/dir/?api=1&destination=\(encoded(address))"
            UIApplication.shared.open(URL(string: web)!)
        }
    }
    
    var body: some View {
        List {
            Section {
                Button {
                    if exhibition.catalogImported {
                        showQuick = true
                    } else {
                        showStartChoice = true
                    }
                } label: {
                    Label("鑑賞モードを開始", systemImage: "square.and.pencil")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Section {
                Text(exhibition.title)
                    .font(.title2).bold()
                    .padding(.bottom, 2)
                // 会場＋地図アイコン（ここから Apple / Google を選べる）
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(exhibition.venue)
                        .font(.subheadline)
                    
                    if (exhibition.address?.isEmpty == false) || (exhibition.coordinate != nil) {
                        Button {
                            showMapChoice = true
                        } label: {
                            Image(systemName: "mappin.circle")
                                .imageScale(.medium)
                                .foregroundStyle(.blue)   // ← 目に入る青
                                .accessibilityLabel("地図アプリで開く")
                        }
                        .buttonStyle(.plain)
                    } else {
                        // 座標未設定の見せ方（任意）
                        Image(systemName: "mappin.slash.circle")
                            .imageScale(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(exhibition.startDate.ymdString) 〜 \(exhibition.endDate.ymdString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } header: {
                Text("概要")
            }
            Section {
                let filledNotes = notes.filter {
                    !$0.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                if filledNotes.isEmpty {
                    Text("鑑賞モードからメモを追加しましょう！")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(filledNotes) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        // 目録番号 + 日付行
                        HStack {
                            Text("#\(n.resolvedDisplayNumber)")
                                .font(.caption)
                                .monospaced()
                            Spacer()
                            Text(n.updatedAt.ymdString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // 作品タイトル
                        if let t = n.artworkTitle, !t.isEmpty {
                            Text(t)
                                .font(.headline)
                        }

                        // 作者 / 制作年 / 技法 / 所蔵 をまとめてサブタイトルに
                        let subtitle = [
                            n.artist,
                            n.yearText,
                            n.material,
                            n.collection
                        ]
                        .compactMap { $0?.isEmpty == false ? $0 : nil }
                        .joined(separator: " / ")

                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // 自分のメモ（空文字は表示しない）
                        let trimmedMemo = n.memo.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedMemo.isEmpty {
                            Text(trimmedMemo)
                                .font(.body)
                        }
                    }
                    .padding(.vertical, 4)
                    }
                }
            } header: {
                HStack {
                    Text("メモ")
                }
            }
            
            if !exhibition.admissionFees.isEmpty || exhibition.reservationRequired == true {
                Section {
                    let userCategory = UserAdmissionCategory(rawValue: userAdmissionCategoryRaw) ?? .adult
                    let resolved = resolvedFee(for: userCategory, fees: exhibition.admissionFees)
                    DisclosureGroup(isExpanded: $showAdmissionDetails) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(exhibition.admissionFees) { fee in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(fee.label)
                                        Spacer()
                                        Text(fee.category == .free || fee.priceYen == nil ? "無料" : "\(fee.priceYen ?? 0)円")
                                            .foregroundStyle(.secondary)
                                    }
                                    if let note = fee.note?.trimmingCharacters(in: .whitespacesAndNewlines),
                                       !note.isEmpty {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        HStack {
                            Text("入館料")
                            Spacer()
                            if let fee = resolved {
                                Text(fee.category == .free || fee.priceYen == nil ? "無料" : "\(fee.priceYen ?? 0)円")
                                    .foregroundStyle(.secondary)
                            }
                            if exhibition.reservationRequired == true {
                                Text("事前予約制")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showAdmissionDetails)
                }
            }
        }
        
        .navigationTitle("詳細")
        .confirmationDialog("目録を読み込んで開始しますか？", isPresented: $showStartChoice) {
            Button("目録を読み込んで開始する") {
                showCatalogImportSheet = true
            }
            Button("後で読み込む") {
                showQuick = true
            }
        }
        .sheet(isPresented: $showQuick) {
            CardPagingNoteView(exhibition: exhibition)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCatalogImportSheet) {
            CatalogImportStartView(exhibition: exhibition) {
                showCatalogImportSheet = false
                showQuick = true
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPlanner) {
            NavigationStack {
                Form {
                    Section("訪問日時") {
                        DatePicker("日付", selection: $visitDate,
                                   in: exhibition.startDate...exhibition.endDate,
                                   displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "ja_JP"))
                            .environment(\.calendar, Calendar(identifier: .gregorian))
                        DatePicker("開始時刻", selection: $visitDate,
                                   displayedComponents: .hourAndMinute)
                    }
                    Section {
                        Text("デフォルトで2時間枠を作成します（後からカレンダーで編集可能）。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("予定に追加")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("閉じる") { showPlanner = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("追加") {
                            Task {
                                // 権限
                                let granted = (try? await EventKitService.shared.requestAccess()) ?? false
                                guard granted else { return }
                                do {
                                    try EventKitService.shared.addVisitEvent(
                                        exhibition: exhibition,
                                        visitDate: visitDate,
                                        durationHours: 2
                                    )
                                    showPlanner = false
                                    showAddDone = true
                                } catch {
                                }
                            }
                        }
                    }
                }
            }
        }
        .alert("カレンダーに追加しました", isPresented: $showAddDone) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $showEdit) {
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
                        visitDate = min(max(Date(), exhibition.startDate), exhibition.endDate)
                        showPlanner = true
                    } label: {
                        Label("カレンダーに追加", systemImage: "calendar.badge.plus")
                    }
                    // 編集
                    Button {
                        showEdit = true
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
                        showDeleteConfirm = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            if let c = exhibition.uiColor {
                pickedColor = Color(c)
            } else {
                pickedColor = .blue
            }
        }
        .confirmationDialog(
            "本当に削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { deleteExhibition() }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "地図で開く",
            isPresented: $showMapChoice,
            titleVisibility: .visible
        ) {
            if let addr = exhibition.address, !addr.isEmpty {
                Button {
                    openInAppleMaps(address: addr)
                } label: { Text("Appleマップで開く") }
                Button {
                    openInGoogleMaps(address: addr)
                } label: { Text("Googleマップで経路案内") }
            } else if let c = exhibition.coordinate {
                Button {
                    openInAppleMaps(c, name: exhibition.title)
                } label: { Text("Appleマップで開く") }
                Button {
                    openInGoogleMaps(c, name: exhibition.title)
                } label: { Text("Googleマップで経路案内") }
            } else {
                // 最後の砦：会場名で検索 または 位置情報未設定の案内
                Button {
                    openInAppleMaps(address: exhibition.venue)
                } label: { Text("Appleマップで開く") }
                Button {
                    openInGoogleMaps(address: exhibition.venue)
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
    
    // Appleマップ（標準）で開く
    private func openInAppleMaps(_ coord: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // Googleマップで経路案内
    private func openInGoogleMaps(_ coord: CLLocationCoordinate2D, name: String) {
        let urlStr = "comgooglemaps://?daddr=\(coord.latitude),\(coord.longitude)&directionsmode=driving"
        if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Google Maps が無ければWebにフォールバック
            let webURL = URL(string: "https://maps.google.com/?q=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            UIApplication.shared.open(webURL)
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
