import SwiftUI

struct BasicInfoSectionView: View {
    @Binding var title: String
    @Binding var venue: String
    @Binding var addressLine: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var urlString: String
    let isAIAnalyzing: Bool
    let isExtracting: Bool
    let isApplyingAutoDates: Bool
    @Binding var hasManuallyEditedDates: Bool
    let onVenueSubmit: () -> Void
    let onTapMap: () -> Void

    var body: some View {
        Section("基本情報") {
            HStack(spacing: 8) {
                Image(systemName: "a.square")
                    .foregroundStyle(.secondary)
                TextField("展覧会名", text: $title)
                    .overlay(alignment: .trailing) {
                        if isAIAnalyzing || isExtracting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
            }
            HStack(spacing: 8) {
                Image(systemName: "building.columns")
                    .foregroundStyle(.secondary)
                TextField("会場", text: $venue)
                    .overlay(alignment: .trailing) {
                        if isAIAnalyzing || isExtracting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .onSubmit(onVenueSubmit)
            }
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.secondary)
                TextField("会場住所（任意）", text: $addressLine)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .overlay(alignment: .trailing) {
                        if isAIAnalyzing || isExtracting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                Button(action: onTapMap) {
                    Image(systemName: "map")
                        .imageScale(.large)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("地図で位置を選ぶ")
            }
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .environment(\.calendar, Calendar.japan)
                    .onChange(of: startDate) { _, _ in
                        if !isApplyingAutoDates { hasManuallyEditedDates = true }
                    }
                    .overlay(alignment: .trailing) {
                        if isAIAnalyzing || isExtracting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
            }
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .environment(\.calendar, Calendar.japan)
                    .onChange(of: endDate) { _, _ in
                        if !isApplyingAutoDates { hasManuallyEditedDates = true }
                    }
                    .overlay(alignment: .trailing) {
                        if isAIAnalyzing || isExtracting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
            }
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField("公式URL（任意）", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .overlay(alignment: .trailing) {
                        if isAIAnalyzing || isExtracting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
            }
        }
    }
}
