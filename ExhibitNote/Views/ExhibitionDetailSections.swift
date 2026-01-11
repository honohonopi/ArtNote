//
//  ExhibitionDetailSections.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI

struct ExhibitionDetailStartSectionView: View {
    let onStart: () -> Void

    var body: some View {
        Section {
            Button(action: onStart) {
                Label("鑑賞モードを開始", systemImage: "square.and.pencil")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

struct ExhibitionDetailSummarySectionView: View {
    let exhibition: Exhibition
    let onTapMap: () -> Void

    var body: some View {
        Section {
            HStack(spacing: 8) {
                Text(exhibition.title)
                    .font(.title2).bold()
                if let url = exhibition.url {
                    Link(destination: url) {
                        Image(systemName: "link")
                            .imageScale(.medium)
                            .foregroundStyle(.blue)
                            .accessibilityLabel("公式サイトを開く")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(exhibition.venue)
                    .font(.subheadline)

                if (exhibition.address?.isEmpty == false) || (exhibition.coordinate != nil) {
                    Button(action: onTapMap) {
                        Image(systemName: "mappin.circle")
                            .imageScale(.medium)
                            .foregroundStyle(.blue)
                            .accessibilityLabel("地図アプリで開く")
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "mappin.slash.circle")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            Text("\(exhibition.startDate.ymdString) 〜 \(exhibition.endDate.ymdString)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        } header: {
            Text("概要")
        }
    }
}

struct ExhibitionDetailDetailsSectionView: View {
    @ObservedObject var vm: ExhibitionDetailViewModel
    let userAdmissionCategoryRaw: String

    var body: some View {
        Section {
            if vm.showDetailSection {
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
                                infoRow(label: "開館時間", value: timeText)
                            }
                            if let lastEntry = vm.exhibition.scheduleLastEntryTime,
                               !lastEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Divider()
                                infoRow(label: "最終入場", value: lastEntry)
                            }
                            if !vm.scheduleClosedWeekdaysText.isEmpty {
                                Divider()
                                infoRow(label: "休館曜日", value: vm.scheduleClosedWeekdaysText)
                            }
                            if let holidayText = vm.holidayHandlingText(vm.exhibition.scheduleHolidayHandling) {
                                Divider()
                                infoRow(label: "祝日対応", value: holidayText)
                            }
                            if !vm.closedDateRules.isEmpty {
                                Divider()
                                ruleListRow(title: "特別休館日", rules: vm.closedDateRules)
                            }
                            if !vm.openDateRules.isEmpty {
                                Divider()
                                ruleListRow(title: "特別開館日", rules: vm.openDateRules)
                            }
                            if !vm.specialOpenings.isEmpty {
                                Divider()
                                specialOpeningsRow(title: "特別開館時間", openings: vm.specialOpenings)
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
        } header: {
            Button {
                vm.showDetailSection.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: vm.showDetailSection ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("詳細")
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }

    private func ruleListRow(title: String, rules: [DateRule]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                Text(vm.dateRuleText(rule))
            }
        }
    }

    private func specialOpeningsRow(title: String, openings: [SpecialOpening]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            ForEach(Array(openings.enumerated()), id: \.offset) { idx, opening in
                if idx > 0 {
                    Divider()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.specialOpeningText(opening))
                    if let last = opening.lastEntryTime, !last.isEmpty {
                        Text("最終入場 \(last)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct ExhibitionDetailMemoSectionView: View {
    let notes: [ArtworkNote]

    var body: some View {
        Section {
            let filledNotes = notes.filter { note in
                let hasMemo = !note.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasArtworkInfo = [
                    note.artworkTitle,
                    note.artist,
                    note.yearText,
                    note.material,
                    note.collection
                ]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .contains { !$0.isEmpty }
                return hasMemo || hasArtworkInfo
            }
            if filledNotes.isEmpty {
                Text("鑑賞モードからメモを追加しましょう！")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(filledNotes) { n in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("#\(n.resolvedDisplayNumber)")
                            .font(.caption)
                            .monospaced()
                        Spacer()
                        Text(n.updatedAt.ymdString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let t = n.artworkTitle, !t.isEmpty {
                        Text(t)
                            .font(.headline)
                    }

                    let subtitle = [
                        n.artist,
                        n.yearText,
                        n.material,
                        n.collection
                    ]
                    .compactMap { $0?.isEmpty == false ? $0 : nil }
                    .joined(separator: " / ")

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    let trimmedMemo = n.memo.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedMemo.isEmpty {
                        Text(trimmedMemo)
                            .font(.body)
                    }
                }
                .padding(.vertical, 4)
                }
            }
        } header: {
            HStack {
                Text("メモ")
            }
        }
    }
}
