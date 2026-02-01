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

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var memoData: Data = MemoRichTextView.emptyData()
    @State private var memoPlainText: String = ""
    @State private var memoAction: MemoAction?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showNumberSuggestions = false
    @State private var previewItem: ImagePreviewItem?

    var body: some View {
        VStack(spacing: 0) {
            MemoRichTextView(
                data: $memoData,
                action: $memoAction,
                onTextChange: { memoPlainText = $0 },
                onImageTap: { image in
                    previewItem = ImagePreviewItem(image: image)
                },
                accessoryView: AnyView(memoKeyboardBar)
            )
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
            ZStack {
                Color.black.ignoresSafeArea()
                CameraPicker { image in
                    if let image {
                        memoAction = .insertImage(image)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .sheet(item: $previewItem) { item in
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: item.image)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                }
                .navigationTitle("写真")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { previewItem = nil }
                    }
                }
            }
        }
        .onAppear {
            if let data = exhibition.memoData, !data.isEmpty {
                memoData = data
            } else {
                memoData = MemoRichTextView.emptyData()
            }
        }
        .onChange(of: memoData) { _, newValue in
            exhibition.memoData = newValue
            exhibition.memoUpdatedAt = .now
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
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            memoAction = .insertImage(image)
        }
        await MainActor.run {
            selectedPhotoItem = nil
        }
    }
}

private enum MemoAction: Equatable {
    case insertText(String)
    case insertImage(UIImage)
    case insertDivider
}

private struct ImagePreviewItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct MemoNumberSuggestionGenerator {
    static func suggestions(from text: String) -> [String] {
        let lastToken = lastNumberToken(in: text)
        if let lastToken, let nextNumbers = nextCandidates(from: lastToken) {
            return nextNumbers
        }
        return (1...5).map { "\($0)" }
    }

    private static func lastNumberToken(in text: String) -> String? {
        let pattern = #"#([A-Za-z0-9_\-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        guard let last = matches.last, last.numberOfRanges > 1 else { return nil }
        guard let range = Range(last.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func nextCandidates(from token: String) -> [String]? {
        let pattern = #"(.*?)(\d+)(\D*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: token.utf16.count)
        guard let match = regex.firstMatch(in: token, options: [], range: range) else { return nil }
        guard let prefixRange = Range(match.range(at: 1), in: token),
              let numberRange = Range(match.range(at: 2), in: token),
              let suffixRange = Range(match.range(at: 3), in: token)
        else { return nil }
        let prefix = String(token[prefixRange])
        let numberText = String(token[numberRange])
        let suffix = String(token[suffixRange])
        guard let base = Int(numberText) else { return nil }
        let width = numberText.count
        return (1...5).map { offset in
            let next = base + offset
            let padded = String(format: "%0*d", width, next)
            return "\(prefix)\(padded)\(suffix)"
        }
    }
}

private struct MemoRichTextView: UIViewRepresentable {
    @Binding var data: Data
    @Binding var action: MemoAction?
    let onTextChange: (String) -> Void
    let onImageTap: (UIImage) -> Void
    let accessoryView: AnyView?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.attributedText = Self.attributedString(from: data)
        context.coordinator.updateAccessory(accessoryView, for: textView)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let hasMarkedText = uiView.markedTextRange != nil
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        if uiView.font != bodyFont {
            uiView.font = bodyFont
        }
        if uiView.typingAttributes[.font] == nil {
            uiView.typingAttributes[.font] = bodyFont
        }
        let attributed = Self.attributedString(from: data)
        if !hasMarkedText && uiView.attributedText != attributed {
            let isEditing = uiView.isFirstResponder
            if !isEditing {
                context.coordinator.isSettingText = true
                let selection = uiView.selectedRange
                let offset = uiView.contentOffset
                uiView.attributedText = attributed
                uiView.selectedRange = selection
                uiView.contentOffset = offset
                context.coordinator.isSettingText = false
            }
        }
        if !hasMarkedText {
            context.coordinator.refreshThumbnailAttachments(in: uiView)
        }
        context.coordinator.updateAccessory(accessoryView, for: uiView)
        if let action = action {
            DispatchQueue.main.async {
                context.coordinator.apply(action, to: uiView, data: $data, onTextChange: onTextChange)
                self.action = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func emptyData() -> Data {
        let attr = NSAttributedString(string: "")
        return (try? attr.data(from: NSRange(location: 0, length: attr.length),
                               documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])) ?? Data()
    }

    static func attributedString(from data: Data) -> NSAttributedString {
        if let attr = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        ) {
            return attr
        }
        return NSAttributedString(string: "")
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: MemoRichTextView
        var isSettingText = false
        private var accessoryHost: UIHostingController<AnyView>?

        init(parent: MemoRichTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isSettingText else { return }
            parent.data = Self.data(from: textView.attributedText)
            parent.onTextChange(textView.text)
            ensureCaretVisible(in: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            updateAccessory(parent.accessoryView, for: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            textView.inputAccessoryView = nil
            textView.reloadInputViews()
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith textAttachment: NSTextAttachment,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            if let image = textAttachment.image ?? imageFromAttachment(textAttachment) {
                DispatchQueue.main.async { self.parent.onImageTap(image) }
                return false
            }
            return true
        }

        func updateAccessory(_ accessory: AnyView?, for textView: UITextView) {
            guard let accessory else {
                textView.inputAccessoryView = nil
                return
            }
        if accessoryHost == nil {
            accessoryHost = UIHostingController(rootView: accessory)
        } else {
            accessoryHost?.rootView = accessory
        }
        guard let host = accessoryHost else { return }
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: 56)
        host.view.frame = CGRect(origin: .zero, size: targetSize)
        textView.inputAccessoryView = host.view
        textView.reloadInputViews()
        }

        func apply(
            _ action: MemoAction,
            to textView: UITextView,
            data: Binding<Data>,
            onTextChange: (String) -> Void
        ) {
            switch action {
            case .insertText(let value):
                insertText(value, in: textView)
            case .insertDivider:
                insertText("\n———————————\n", in: textView)
            case .insertImage(let image):
                insertImage(image, in: textView)
            }
            data.wrappedValue = Self.data(from: textView.attributedText)
            onTextChange(textView.text)
            if case .insertImage = action {
                ensureCaretVisible(in: textView)
            }
        }

        private func insertText(_ text: String, in textView: UITextView) {
            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
            let attr = NSAttributedString(string: text, attributes: [.font: font])
            let range = textView.selectedRange
            textView.textStorage.replaceCharacters(in: range, with: attr)
            let cursor = range.location + attr.length
            textView.selectedRange = NSRange(location: cursor, length: 0)
        }

        private func insertImage(_ image: UIImage, in textView: UITextView) {
            let targetSize = Self.thumbnailSize(for: image)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            let resizedData = resized.pngData()
            let attachment = NSTextAttachment(data: resizedData, ofType: "public.png")
            attachment.image = resized
            attachment.bounds = CGRect(origin: .zero, size: targetSize)
            let attr = NSAttributedString(attachment: attachment)
            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
            let newline = NSAttributedString(string: "\n", attributes: [.font: font])
            let range = textView.selectedRange
            let insert = NSMutableAttributedString()
            insert.append(newline)
            insert.append(attr)
            insert.append(newline)
            textView.textStorage.replaceCharacters(in: range, with: insert)
            let cursor = range.location + newline.length + attr.length + newline.length
            textView.selectedRange = NSRange(location: cursor, length: 0)
            textView.typingAttributes = [.font: font]
            ensureCaretVisible(in: textView)
        }

        private static func data(from attributed: NSAttributedString) -> Data {
            (try? attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )) ?? Data()
        }

        private func imageFromAttachment(_ attachment: NSTextAttachment) -> UIImage? {
            if let data = attachment.fileWrapper?.regularFileContents,
               let image = UIImage(data: data) {
                return image
            }
            return nil
        }

        func refreshThumbnailAttachments(in textView: UITextView) {
            if textView.markedTextRange != nil { return }
            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            var didChange = false
            mutable.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                guard let attachment = value as? NSTextAttachment else { return }
                guard let image = attachment.image ?? imageFromAttachment(attachment) else { return }
                let targetSize = Self.thumbnailSize(for: image)
                let resized = UIGraphicsImageRenderer(size: targetSize).image { _ in
                    image.draw(in: CGRect(origin: .zero, size: targetSize))
                }
                if attachment.bounds.size != targetSize || attachment.image?.size != resized.size {
                    let resizedData = resized.pngData()
                    let newAttachment = NSTextAttachment(data: resizedData, ofType: "public.png")
                    newAttachment.image = resized
                    newAttachment.bounds = CGRect(origin: .zero, size: targetSize)
                    mutable.replaceCharacters(in: range, with: NSAttributedString(attachment: newAttachment))
                    didChange = true
                }
            }
            if didChange {
                let selection = textView.selectedRange
                if textView.isFirstResponder {
                    textView.textStorage.setAttributedString(mutable)
                    textView.selectedRange = selection
                } else {
                    let offset = textView.contentOffset
                    textView.attributedText = mutable
                    textView.selectedRange = selection
                    textView.contentOffset = offset
                }
            }
        }

        private static func thumbnailSize(for image: UIImage) -> CGSize {
            let maxWidth: CGFloat = 160
            let maxHeight: CGFloat = 160
            let scale = min(maxWidth / image.size.width, maxHeight / image.size.height, 1)
            return CGSize(width: image.size.width * scale, height: image.size.height * scale)
        }

        private func ensureCaretVisible(in textView: UITextView) {
            let range = textView.selectedRange
            if range.location != NSNotFound {
                textView.scrollRangeToVisible(range)
            }
        }
    }
}
