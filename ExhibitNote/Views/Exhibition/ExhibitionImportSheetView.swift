//
//  ExhibitionImportSheetView.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import SwiftUI

struct ExhibitionImportSheetView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var context
    @StateObject private var writeState = ExhibitionWriteState()
    @StateObject private var vm: ExhibitionImportViewModel
    @Environment(\.dismiss) private var dismiss

    init(payload: ExhibitionSharePayload, onComplete: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: ExhibitionImportViewModel(payload: payload))
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundStyle(.secondary)
                            Text("ポスター画像")
                        }
                        Spacer()
                        posterPreviewInline
                    }
                    HStack {
                        Image(systemName: "a.square")
                            .foregroundStyle(.secondary)
                        Text("展覧会名")
                        Spacer()
                        Text(vm.payload.title)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "building.columns")
                            .foregroundStyle(.secondary)
                        Text("会場")
                        Spacer()
                        Text(vm.payload.venue)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text("会期")
                        Spacer()
                        Text(vm.periodText)
                            .foregroundStyle(.secondary)
                    }
                    if let address = vm.payload.address, !address.isEmpty {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(.secondary)
                            Text("住所")
                            Spacer()
                            Text(address)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let url = vm.payload.url, !url.isEmpty {
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.secondary)
                            Text("URL")
                            Spacer()
                            Text(url)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                if !vm.payload.admissionFees.isEmpty || vm.payload.reservationRequired != nil {
                    Section("入館情報") {
                        let displayFees = vm.admissionFeesForDisplay
                        VStack(alignment: .leading, spacing: 6) {
                            if !displayFees.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "chineseyuanrenminbisign")
                                            .foregroundStyle(.secondary)
                                        Text("入館料")
                                    }
                                    .padding(.vertical, 4)
                                    Divider()
                                        .padding(.leading, 20)
                                    ForEach(Array(displayFees.enumerated()), id: \.element.id) { index, fee in
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
                                            .padding(.vertical, 2)
                                            if let note = fee.note?.trimmingCharacters(in: .whitespacesAndNewlines),
                                               !note.isEmpty {
                                                Text(note)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.leading, 20)
                                        if index < displayFees.count - 1 {
                                            Divider()
                                                .padding(.leading, 20)
                                        }
                                    }
                                }
                            }
                            if let required = vm.payload.reservationRequired {
                                if !displayFees.isEmpty {
                                    Divider()
                                }
                                HStack {
                                    Image(systemName: "info")
                                        .foregroundStyle(.secondary)
                                    Text("予約情報")
                                    Spacer()
                                    Text(required ? "事前予約制" : "予約不要")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                if let schedule = vm.payload.schedule {
                    Section("開館情報") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.secondary)
                                Text("開館情報")
                            }
                            .padding(.vertical, 4)
                            Divider()
                                .padding(.leading, 20)
                            if let open = schedule.openTime, let close = schedule.closeTime {
                                HStack {
                                    Text("開館時間")
                                    Spacer()
                                    Text("\(open)〜\(close)")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 20)
                                .padding(.vertical, 4)
                                Divider()
                                    .padding(.leading, 20)
                            }
                            if let last = schedule.lastEntryTime, !last.isEmpty {
                                HStack {
                                    Text("最終入場")
                                    Spacer()
                                    Text(last)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 20)
                                .padding(.vertical, 4)
                                Divider()
                                    .padding(.leading, 20)
                            }
                            if !schedule.closedWeekdays.isEmpty {
                                HStack {
                                    Text("休館曜日")
                                    Spacer()
                                    Text(vm.weekdayLabel(schedule.closedWeekdays))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 20)
                                .padding(.vertical, 4)
                                Divider()
                                    .padding(.leading, 20)
                            }
                            if let handling = schedule.holidayHandling, !handling.isEmpty {
                                HStack {
                                    Text("祝日対応")
                                    Spacer()
                                    Text(vm.holidayHandlingLabel(handling))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 20)
                                .padding(.vertical, 4)
                                Divider()
                                    .padding(.leading, 20)
                            }
                            if !schedule.closedDateRules.isEmpty {
                                HStack(alignment: .top) {
                                    Text("特別休館日")
                                    Spacer()
                                    Text(vm.dateRulesText(schedule.closedDateRules))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                                .padding(.leading, 20)
                                .padding(.vertical, 4)
                                Divider()
                                    .padding(.leading, 20)
                            }
                            if !schedule.openDateRules.isEmpty {
                                HStack(alignment: .top) {
                                    Text("特別開館日")
                                    Spacer()
                                    Text(vm.dateRulesText(schedule.openDateRules))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                                .padding(.leading, 20)
                                .padding(.vertical, 4)
                                Divider()
                                    .padding(.leading, 20)
                            }
                            if !schedule.specialOpenings.isEmpty {
                                HStack(alignment: .top) {
                                    Text("特別開館時間")
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        ForEach(Array(schedule.specialOpenings.enumerated()), id: \.element.id) { index, record in
                                            let parts = vm.specialOpeningText(record)
                                            Text(parts.main)
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.trailing)
                                            if let last = parts.lastEntry {
                                                Text(last)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .multilineTextAlignment(.trailing)
                                            }
                                            if index < schedule.specialOpenings.count - 1 {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                                .padding(.leading, 20)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("共有された展覧会")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                        onComplete()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("登録する") {
                        register()
                    }
                }
            }
        }
        .exhibitionWriteFeedback(writeState)
        .task {
            await vm.loadPosterThumbnail()
        }
    }

    private func register() {
        let exhibition = vm.makeExhibition()
        writeState.run {
            try await ExhibitionPersistenceService(context: context).insert(exhibition)
            dismiss()
            onComplete()
        }
    }

    @ViewBuilder
    private var posterPreviewInline: some View {
        if let data = vm.posterThumbData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if vm.isLoadingPoster {
            ProgressView()
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }

}
