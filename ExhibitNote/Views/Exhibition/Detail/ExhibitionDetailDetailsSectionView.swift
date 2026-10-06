import SwiftUI

struct ExhibitionDetailDetailsSectionView: View {
    @Bindable var vm: ExhibitionDetailViewModel
    let userAdmissionCategoryRaw: String

    var body: some View {
        Section("詳細") {
            let hasAdmissionInfo = !vm.exhibition.admissionFeeRules.isEmpty || vm.exhibition.reservationRequired != nil
            let resolved = vm.resolvedAdmissionFee(for: userAdmissionCategoryRaw)
            if hasAdmissionInfo {
                DisclosureGroup(isExpanded: $vm.showAdmissionDetails) {
                    VStack(alignment: .leading, spacing: 8) {
                        let displayFees = vm.displayAdmissionFees
                        if displayFees.isEmpty {
                            Text("料金情報がありません")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(displayFees.enumerated()), id: \.element.id) { idx, fee in
                            if idx > 0 {
                                Divider()
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(fee.rawLabel)
                                    Spacer()
                                    if fee.isFreeLike {
                                        Text("無料")
                                            .foregroundStyle(.secondary)
                                    } else if let price = fee.priceYen {
                                        Text("\(price)円")
                                            .foregroundStyle(.secondary)
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
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    HStack {
                        Text("入館情報")
                        Spacer()
                        if let fee = resolved {
                            if fee.isFreeLike {
                                Text("無料")
                                    .foregroundStyle(.secondary)
                            } else if let price = fee.priceYen {
                                Text("\(price)円")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if vm.exhibition.reservationRequired != nil {
                            Text(vm.reservationStatusText(vm.exhibition.reservationRequired))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: vm.showAdmissionDetails)
            } else {
                HStack {
                    Text("入館情報")
                    Spacer()
                    Text("情報がありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if vm.hasScheduleInfo {
                DisclosureGroup(isExpanded: $vm.showScheduleDetails) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let timeText = vm.scheduleTimeText {
                            ExhibitionDetailInfoRow(label: "開館時間", value: timeText)
                        }
                        if let lastEntry = vm.exhibition.scheduleLastEntryTime,
                           !lastEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Divider()
                            ExhibitionDetailInfoRow(label: "最終入場", value: lastEntry)
                        }
                        if !vm.scheduleClosedWeekdaysText.isEmpty {
                            Divider()
                            ExhibitionDetailInfoRow(label: "休館曜日", value: vm.scheduleClosedWeekdaysText)
                        }
                        if let holidayText = vm.holidayHandlingText(vm.exhibition.scheduleHolidayHandling) {
                            Divider()
                            ExhibitionDetailInfoRow(label: "祝日対応", value: holidayText)
                        }
                        if !vm.closedDateRules.isEmpty {
                            Divider()
                            ExhibitionDetailDateRulesRow(
                                title: "特別休館日",
                                rules: vm.closedDateRules,
                                text: vm.dateRuleText
                            )
                        }
                        if !vm.openDateRules.isEmpty {
                            Divider()
                            ExhibitionDetailDateRulesRow(
                                title: "特別開館日",
                                rules: vm.openDateRules,
                                text: vm.dateRuleText
                            )
                        }
                        if !vm.specialOpenings.isEmpty {
                            Divider()
                            ExhibitionDetailSpecialOpeningsRow(
                                title: "特別開館時間",
                                openings: vm.specialOpenings,
                                text: vm.specialOpeningText
                            )
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    HStack {
                        Text("開館情報")
                        Spacer()
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: vm.showScheduleDetails)
            } else {
                HStack {
                    Text("開館情報")
                    Spacer()
                    Text("情報がありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

}
