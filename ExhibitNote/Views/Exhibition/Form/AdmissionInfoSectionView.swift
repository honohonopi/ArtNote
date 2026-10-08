import SwiftUI

struct AdmissionInfoSectionView: View {
    @Binding var showAdmissionFees: Bool
    @Binding var admissionFees: [AdmissionFeeRule]
    @Binding var reservationRequired: Bool?

    let isAIAnalyzing: Bool
    let admissionPriceText: (AdmissionFeeRule) -> String?
    let reservationStatusText: (Bool?) -> String
    let onAddFee: () -> Void
    let onEditFee: (Int) -> Void

    private var displayAdmissionFeeIndices: [Int] {
        admissionFees.indices.filter { idx in
            let fee = admissionFees[idx]
            return fee.priceYen != nil ||
                (fee.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }
    }

    var body: some View {
        Section("入館情報") {
            DisclosureGroup(isExpanded: $showAdmissionFees) {
                Button(action: onAddFee) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                        Text("入館料を追加")
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                ForEach(displayAdmissionFeeIndices, id: \.self) { idx in
                    let fee = admissionFees[idx]
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(fee.rawLabel)
                            Spacer()
                            if let priceText = admissionPriceText(fee) {
                                Text(priceText)
                                    .foregroundStyle(.primary)
                            }
                            Menu {
                                Button("編集") { onEditFee(idx) }
                                Button("削除", role: .destructive) {
                                    admissionFees.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.blue)
                            }
                        }
                        if let note = fee.note?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chineseyuanrenminbisign")
                        .foregroundStyle(.secondary)
                    Text("入館料")
                        .foregroundStyle(.primary)
                    Spacer()
                    if isAIAnalyzing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showAdmissionFees)
            HStack(spacing: 8) {
                Image(systemName: "info")
                    .foregroundStyle(.secondary)
                Text("予約情報")
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    Button("記載なし") { reservationRequired = nil }
                    Button("予約不要") { reservationRequired = false }
                    Button("事前予約制") { reservationRequired = true }
                } label: {
                    HStack(spacing: 6) {
                        Text(reservationStatusText(reservationRequired))
                            .foregroundStyle(.black)
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
                if isAIAnalyzing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
    }
}
