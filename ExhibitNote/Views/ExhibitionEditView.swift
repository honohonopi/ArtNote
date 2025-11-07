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
import PhotosUI
import UIKit

struct ExhibitionEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var venue: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var color: Color
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var localPreviewImage: UIImage? = nil   // 直近で選んだ画像のプレビュー
    @State private var showLibrary = false
    
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
                // 追加：ポスター差し替え
                Section("ポスター") {
                    HStack(spacing: 12) {
                        // プレビュー（サムネ or 直近選択画像 or プレースホルダ）
                        PosterPreviewView(
                            data: exhibition.posterThumbData,
                            fallbackColor: (exhibition.swiftUIColor ?? .gray)
                        )
                        .overlay(
                            Group {
                                if let img = localPreviewImage {
                                    // 直近に選択した画像を一時的に被せて見せる
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                        )
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Menu {
                            Button {
                                showLibrary = true   // ← PhotosPicker を表示
                            } label: {
                                Label("写真ライブラリから選ぶ", systemImage: "photo.on.rectangle")
                            }
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showCamera = true
                                } label: {
                                    Label("カメラで撮る", systemImage: "camera.viewfinder")
                                }
                            }
                            if exhibition.posterThumbData != nil {
                                Button(role: .destructive) {
                                    exhibition.posterThumbData = nil
                                    localPreviewImage = nil
                                } label: {
                                    Label("ポスターを削除", systemImage: "trash")
                                }
                            }
                        } label: {
                            Label("ポスター画像を変更", systemImage: "text.viewfinder")
                        }
                    }
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
            // MARK: - ライブラリ（PhotosPicker）
            .sheet(isPresented: $showLibrary) {
                PhotoLibraryPicker { image in
                    if let img = image { handlePickedImage(img) }
                    showLibrary = false
                }
            }
            // MARK: - カメラ
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    if let img = image { handlePickedImage(img) }
                    showCamera = false
                }
            }
        }
    }
    // MARK: - 画像を受け取ってモデルへ反映
    private func handlePickedImage(_ image: UIImage) {
        // サムネ生成（軽量化して保存）
        if let thumb = ImageThumbService.makeThumbnail(image) {
            exhibition.posterThumbData = thumb
        }
        // 編集画面内の即時プレビュー
        localPreviewImage = image

        // （任意）支配色をテーマに反映したい場合：
         if let ui = DominantColorService.dominantColor(from: image) {
             color = Color(ui)
             exhibition.setColor(ui)
         }
    }

    // MARK: - プレビュー（サムネ or フォールバック）
    private struct PosterPreviewView: View {
        let data: Data?
        let fallbackColor: Color
        var body: some View {
            if let d = data, let ui = UIImage(data: d) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    fallbackColor.opacity(0.15)
                    Image(systemName: "photo.on.rectangle")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - CameraPicker（UIKit ラッパー）
    private struct CameraPicker: UIViewControllerRepresentable {
        var onComplete: (UIImage?) -> Void
        func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }
        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.allowsEditing = false
            picker.delegate = context.coordinator
            return picker
        }
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
        final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
            let onComplete: (UIImage?) -> Void
            init(onComplete: @escaping (UIImage?) -> Void) { self.onComplete = onComplete }
            func imagePickerController(_ picker: UIImagePickerController,
                                       didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                let img = (info[.originalImage] as? UIImage)
                picker.dismiss(animated: true) { self.onComplete(img) }
            }
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                picker.dismiss(animated: true) { self.onComplete(nil) }
            }
        }
    }
    // MARK: - PhotoLibraryPicker (PHPicker ラッパー)
    private struct PhotoLibraryPicker: UIViewControllerRepresentable {
        var onComplete: (UIImage?) -> Void

        func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

        func makeUIViewController(context: Context) -> PHPickerViewController {
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.selectionLimit = 1
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

        final class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let onComplete: (UIImage?) -> Void
            init(onComplete: @escaping (UIImage?) -> Void) { self.onComplete = onComplete }

            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                guard let first = results.first else {
                    picker.dismiss(animated: true) { self.onComplete(nil) }
                    return
                }
                let provider = first.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        DispatchQueue.main.async {
                            picker.dismiss(animated: true) {
                                self.onComplete(image as? UIImage)
                            }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                        let img = data.flatMap { UIImage(data: $0) }
                        DispatchQueue.main.async {
                            picker.dismiss(animated: true) {
                                self.onComplete(img)
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        picker.dismiss(animated: true) { self.onComplete(nil) }
                    }
                }
            }
        }
    }


}

