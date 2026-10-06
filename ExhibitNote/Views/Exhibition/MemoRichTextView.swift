import SwiftUI
import UIKit

enum MemoAction: Equatable {
    case insertText(String)
    case insertImage(UIImage)
    case insertDivider
}

struct MemoRichTextView: UIViewRepresentable {
    @Binding var data: Data
    @Binding var action: MemoAction?
    let onTextChange: (String) -> Void
    let onEditingEnd: (Data) -> Void
    let onImageTap: (UIImage) -> Void
    let accessoryView: AnyView?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.attributedText = Self.attributedString(from: data)
        context.coordinator.displayedData = data
        context.coordinator.refreshThumbnailAttachments(in: textView)
        textView.delegate = context.coordinator
        context.coordinator.updateAccessory(accessoryView, for: textView)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        let hasMarkedText = uiView.markedTextRange != nil
        if !hasMarkedText,
           !uiView.isFirstResponder,
           context.coordinator.displayedData != data {
            context.coordinator.isSettingText = true
            let selection = uiView.selectedRange
            let offset = uiView.contentOffset
            uiView.attributedText = Self.attributedString(from: data)
            context.coordinator.refreshThumbnailAttachments(in: uiView)
            uiView.selectedRange = selection
            uiView.contentOffset = offset
            context.coordinator.displayedData = data
            context.coordinator.isSettingText = false
        }
        if let action = action {
            DispatchQueue.main.async {
                context.coordinator.apply(action, to: uiView, onTextChange: onTextChange)
                self.action = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        coordinator.saveCurrentContent(of: uiView)
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
        var parent: MemoRichTextView
        var isSettingText = false
        var displayedData: Data?
        private var accessoryHost: UIHostingController<AnyView>?

        init(parent: MemoRichTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isSettingText else { return }
            parent.onTextChange(textView.text)
            ensureCaretVisible(in: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            saveCurrentContent(of: textView)
        }

        func saveCurrentContent(of textView: UITextView) {
            let newData = Self.data(from: textView.attributedText)
            displayedData = newData
            parent.data = newData
            parent.onEditingEnd(newData)
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
                if textView.inputAccessoryView != nil {
                    textView.inputAccessoryView = nil
                    if textView.isFirstResponder {
                        textView.reloadInputViews()
                    }
                }
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
            let targetSize = CGSize(width: textView.bounds.width, height: 56)
            host.view.frame = CGRect(origin: .zero, size: targetSize)
            guard textView.inputAccessoryView !== host.view else { return }
            textView.inputAccessoryView = host.view
            if textView.isFirstResponder {
                textView.reloadInputViews()
            }
        }

        func apply(
            _ action: MemoAction,
            to textView: UITextView,
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
