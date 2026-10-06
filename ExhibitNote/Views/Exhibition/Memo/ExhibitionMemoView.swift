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
    let exhibition: Exhibition

    @State private var memoData = Data()
    @State private var memoPlainText: String = ""
    @State private var memoAction: MemoAction?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showNumberSuggestions = false
    @State private var previewItem: MemoImagePreviewItem?

    var body: some View {
        VStack(spacing: 0) {
            MemoRichTextView(
                data: $memoData,
                action: $memoAction,
                onTextChange: { memoPlainText = $0 },
                onEditingEnd: { saveMemo($0) },
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
                    memoAction = .insertImage(image)
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .sheet(item: $previewItem) { item in
            MemoImagePreviewView(image: item.image)
        }
        .onAppear {
            if let data = exhibition.memoData, !data.isEmpty {
                memoData = data
            } else {
                memoData = Data()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                await insertPhoto(from: newValue)
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
                let suggestions = MemoNumberSuggestionGenerator.suggestions(from: memoPlainText)
                if suggestions.isEmpty {
                    memoAction = .insertText("#")
                } else {
                    showNumberSuggestions.toggle()
                }
            } label: {
                toolbarItem(label: "作品番号", textSymbol: "#")
            }
            Spacer()
            Button {
                memoAction = .insertDivider
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
        let suggestions = MemoNumberSuggestionGenerator.suggestions(from: memoPlainText)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("作品番号")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                ForEach(suggestions, id: \.self) { value in
                    Button {
                        memoAction = .insertText("#\(value) ")
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

    private func insertPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let image = await item.loadUIImage() {
            memoAction = .insertImage(image)
        }
        await MainActor.run {
            selectedPhotoItem = nil
        }
    }

    private func saveMemo(_ data: Data? = nil) {
        let dataToSave = data ?? memoData
        guard exhibition.memoData != dataToSave else { return }
        exhibition.memoData = dataToSave
        exhibition.memoUpdatedAt = .now
    }
}
