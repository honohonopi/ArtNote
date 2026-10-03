import SwiftUI

/// Keeps the form open on write failure and prevents duplicate submissions.
@MainActor
final class ExhibitionWriteState: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var errorMessage: String?
    @Published private(set) var errorTitle = "保存できませんでした"

    func run(
        deleting: Bool = false,
        _ operation: @escaping @MainActor () async throws -> Void
    ) {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        errorTitle = deleting ? "削除できませんでした" : "保存できませんでした"
        Task { @MainActor in
            defer { isRunning = false }
            do {
                try await operation()
            } catch {
                let message = deleting
                    ? "展覧会を削除できませんでした。もう一度お試しください。"
                    : "変更を保存できませんでした。入力内容はこの画面に残っています。もう一度お試しください。"
                errorMessage = "\(message)\n\n\(error.localizedDescription)"
            }
        }
    }
}

private struct ExhibitionWriteFeedback: ViewModifier {
    @ObservedObject var state: ExhibitionWriteState

    func body(content: Content) -> some View {
        content
            .disabled(state.isRunning)
            .interactiveDismissDisabled(state.isRunning)
            .navigationBarBackButtonHidden(state.isRunning)
            .overlay {
                if state.isRunning { ProgressView("処理中…") }
            }
            .alert(state.errorTitle, isPresented: Binding(
                get: { state.errorMessage != nil },
                set: { if !$0 { state.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { state.errorMessage = nil }
            } message: {
                Text(state.errorMessage ?? "")
            }
    }
}

extension View {
    func exhibitionWriteFeedback(_ state: ExhibitionWriteState) -> some View {
        modifier(ExhibitionWriteFeedback(state: state))
    }
}
