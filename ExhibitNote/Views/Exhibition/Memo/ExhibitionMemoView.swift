//
//  ExhibitionMemoView.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import SwiftUI
import PhotosUI
import UIKit

struct ExhibitionMemoView: View {
    @State private var vm: ExhibitionMemoViewModel
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showNumberSuggestions = false
    @State private var previewItem: MemoImagePreviewItem?

    init(exhibition: Exhibition) {
        _vm = State(initialValue: ExhibitionMemoViewModel(exhibition: exhibition))
    }

    var body: some View {
        VStack(spacing: 0) {
            MemoRichTextView(
                data: $vm.memoData,
                action: $vm.memoAction,
                onTextChange: vm.updatePlainText,
                onEditingEnd: vm.save,
                onImageTap: { image in
                    previewItem = MemoImagePreviewItem(image: image)
                },
                accessoryView: AnyView(memoKeyboardBar)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .navigationTitle("展覧会メモ")
        .navigationBarTitleDisplayMode(.inline)
        .simultaneousGesture(
            TapGesture().onEnded {
                if showNumberSuggestions {
                    showNumberSuggestions = false
                }
            }
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(uiColor: .systemBlue))
                }
                .accessibilityLabel("キーボードを閉じる")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showNumberSuggestions {
                numberSuggestionBar
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image {
                    vm.insertCameraImage(image)
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .sheet(item: $previewItem) { item in
            MemoImagePreviewView(image: item.image)
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                await vm.insertPhoto(from: newValue)
                selectedPhotoItem = nil
            }
        }
    }

    private var memoKeyboardBar: some View {
        let barHeight: CGFloat = 48
        return HStack {
            Spacer()
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                showCamera = true
            } label: {
                toolbarItem(label: "カメラ", systemImage: "camera")
            }
            Spacer()
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                showPhotoPicker = true
            } label: {
                toolbarItem(label: "写真", systemImage: "photo.on.rectangle")
            }
            Spacer()
            Button {
                let suggestions = vm.numberSuggestions
                if suggestions.isEmpty {
                    vm.insertNumberMarker()
                } else {
                    showNumberSuggestions.toggle()
                }
            } label: {
                toolbarItem(label: "作品番号", textSymbol: "#")
            }
            Spacer()
            Button {
                vm.insertDivider()
            } label: {
                toolbarItem(label: "区切り線", systemImage: "minus")
            }
            Spacer()
        }
        .frame(height: barHeight)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .frame(height: 48)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private func toolbarItem(label: String, systemImage: String? = nil, textSymbol: String? = nil) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Color.clear.frame(height: 20)
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                } else if let textSymbol {
                    Text(textSymbol)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            Text(label)
                .font(.caption2)
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
    }

    private var numberSuggestionBar: some View {
        let suggestions = vm.numberSuggestions
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("作品番号")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                ForEach(suggestions, id: \.self) { value in
                    Button {
                        vm.insertNumber(value)
                        showNumberSuggestions = false
                    } label: {
                        Text("#\(value)")
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 7)
                            .padding(.horizontal, 12)
                            .foregroundStyle(.primary)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .systemBackground).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

}
