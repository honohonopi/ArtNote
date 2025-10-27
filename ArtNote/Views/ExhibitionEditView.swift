//
//  ExhibitionEditView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/28.
//

import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct ExhibitionEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var venue: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var color: Color
    
    @State private var addressLine: String = ""
    @State private var tempCoordinate: CLLocationCoordinate2D? = nil
    @State private var mapPickerPayload: MapPayload? = nil
    @State private var previewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    private struct MapPayload: Identifiable { let id = UUID(); let query: String }
    private struct IdentCoord: Identifiable { let id = UUID(); let coord: CLLocationCoordinate2D }
    
    let exhibition: Exhibition
    
    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        _title = State(initialValue: exhibition.title)
        _venue = State(initialValue: exhibition.venue)
        _addressLine = State(initialValue: exhibition.address ?? "")
        _startDate = State(initialValue: exhibition.startDate)
        _endDate = State(initialValue: exhibition.endDate)
        if let ui = exhibition.uiColor { _color = State(initialValue: Color(ui)) }
        else { _color = State(initialValue: .blue) }
        if let c = exhibition.coordinate {
            _tempCoordinate = State(initialValue: c)
            _previewRegion = State(initialValue:
                                    MKCoordinateRegion(center: c, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01))
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("展覧会名", text: $title)
                    TextField("会場", text: $venue)
                    HStack(spacing: 8) {
                        TextField("会場住所（任意）", text: $addressLine)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        Button {
                            // 住所 > 会場 > どちらも空なら何もしない
                            let q = addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? venue.trimmingCharacters(in: .whitespacesAndNewlines)
                            : addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !q.isEmpty else { return }
                            mapPickerPayload = .init(query: q)
                        } label: {
                            Image(systemName: "mappin.and.ellipse")
                                .imageScale(.large)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("地図で位置を選ぶ")
                    }
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                    DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                }
                Section("帯の色") {
                    ColorPicker("色", selection: $color, supportsOpacity: false)
                }
            }
            .navigationTitle("編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 日付の整合性
                        if endDate < startDate { endDate = startDate }
                        // モデルへ反映
                        exhibition.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        exhibition.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
                        exhibition.address = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        exhibition.startDate = startDate
                        exhibition.endDate = endDate
                        exhibition.setColor(UIColor(color))
                        if let c = tempCoordinate {
                            exhibition.setCoordinate(c)
                        } else {
                        }
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .sheet(item: $mapPickerPayload) { payload in
                NavigationStack {
                    MapPickerView(seed: tempCoordinate, initialQuery: payload.query) { pickedCoord, pickedAddress in
                        // 反映
                        tempCoordinate = pickedCoord
                        previewRegion.center = pickedCoord
                        previewRegion.span = .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        if let addr = pickedAddress, !addr.isEmpty {
                            // 住所が未入力なら埋める（常に上書きしたい場合は else 側を上書きに）
                            if addressLine.isEmpty { addressLine = addr }
                        }
                    }
                }
            }
            
        }
    }
}

