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
    
    @State private var showPlanner = false
    @State private var visitDate = Date()
    @State private var showAddDone = false
    
    @State private var showMapChoice = false
    
    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        let exId = exhibition.id
        _notes = Query(filter: #Predicate<ArtworkNote> { n in n.exhibitionId == exId },
                       sort: [SortDescriptor(\.catalogNumber, order: .forward)])
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
                    showQuick = true
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
            Section("メモ（\(notes.count)）") {
                ForEach(notes) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("#\(n.catalogNumber)").font(.caption).monospaced()
                            Spacer()
                            Text(n.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(n.memo).font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        
        .navigationTitle("詳細")
        .sheet(isPresented: $showQuick) {
            CardPagingNoteView(exhibition: exhibition)
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

