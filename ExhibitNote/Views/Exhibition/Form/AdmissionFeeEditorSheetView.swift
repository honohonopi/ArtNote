import SwiftUI

struct AdmissionFeeEditorSheetView: View {
    @Binding var editingAdmissionFeeIndex: Int?
    @Binding var showAdmissionFeeEditor: Bool
    @Binding var draftAdmissionLabel: String
    @Binding var draftAdmissionPriceText: String
    @Binding var draftAdmissionNote: String
    let canSaveAdmissionFee: Bool
    let onCommit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("区分") {
                    TextField("例: 一般 / 高校生・大学生", text: $draftAdmissionLabel)
                        .textInputAutocapitalization(.never)
                }
                Section("金額") {
                    TextField("例: 1200（空欄可）", text: $draftAdmissionPriceText)
                        .keyboardType(.numberPad)
                }
                Section("メモ") {
                    TextField("任意", text: $draftAdmissionNote)
                }
            }
            .navigationTitle(editingAdmissionFeeIndex == nil ? "入館料を追加" : "入館料を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        editingAdmissionFeeIndex = nil
                        showAdmissionFeeEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingAdmissionFeeIndex == nil ? "追加" : "保存") {
                        onCommit()
                        showAdmissionFeeEditor = false
                    }
                    .disabled(!canSaveAdmissionFee)
                }
            }
        }
    }
}
