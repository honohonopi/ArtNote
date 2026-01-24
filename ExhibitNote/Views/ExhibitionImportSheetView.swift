//
//  ExhibitionImportSheetView.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import SwiftUI

struct ExhibitionImportSheetView: View {
    let payload: ExhibitionSharePayload
    let onComplete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var posterThumbData: Data?
    @State private var isLoadingPoster = false

    var body: some View {
        NavigationStack {
            Form {
                Section("展覧会情報") {
                    posterPreview
                    HStack {
                        Text("展覧会名")
                        Spacer()
                        Text(payload.title)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("会場")
                        Spacer()
                        Text(payload.venue)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("会期")
                        Spacer()
                        Text("\(payload.startDate)〜\(payload.endDate)")
                            .foregroundStyle(.secondary)
                    }
                    if let address = payload.address, !address.isEmpty {
                        HStack {
                            Text("住所")
                            Spacer()
                            Text(address)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let url = payload.url, !url.isEmpty {
                        HStack {
                            Text("URL")
                            Spacer()
                            Text(url)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                if !payload.admissionFees.isEmpty || payload.reservationRequired != nil {
                    Section("入館情報") {
                        if !payload.admissionFees.isEmpty {
                            ForEach(payload.admissionFees) { fee in
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
                        if let required = payload.reservationRequired {
                            Text(required ? "事前予約制" : "予約不要")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let schedule = payload.schedule {
                    Section("開館情報") {
                        if let open = schedule.openTime, let close = schedule.closeTime {
                            HStack {
                                Text("開館時間")
                                Spacer()
                                Text("\(open)〜\(close)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let last = schedule.lastEntryTime, !last.isEmpty {
                            HStack {
                                Text("最終入場")
                                Spacer()
                                Text(last)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !schedule.closedWeekdays.isEmpty {
                            HStack {
                                Text("休館曜日")
                                Spacer()
                                Text(weekdayLabel(schedule.closedWeekdays))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let handling = schedule.holidayHandling, !handling.isEmpty {
                            HStack {
                                Text("祝日対応")
                                Spacer()
                                Text(holidayHandlingLabel(handling))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !schedule.closedDateRules.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("特別休館日")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(schedule.closedDateRules, id: \.id) { rule in
                                    Text(dateRuleText(rule))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if !schedule.openDateRules.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("特別開館日")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(schedule.openDateRules, id: \.id) { rule in
                                    Text(dateRuleText(rule))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if !schedule.specialOpenings.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("特別開館時間")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(schedule.specialOpenings, id: \.id) { record in
                                    Text(specialOpeningText(record))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    Text("この美術展を登録しますか？")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        .task {
            await loadPosterThumb()
        }
    }

    private func register() {
        let start = ExhibitionShareService.parseDate(payload.startDate) ?? Date()
        let end = ExhibitionShareService.parseDate(payload.endDate) ?? start
        let ex = Exhibition(
            title: payload.title,
            venue: payload.venue,
            address: payload.address,
            startDate: start,
            endDate: max(start, end),
            url: payload.url.flatMap { $0.normalizedWebURL() }
        )
        if let lat = payload.latitude, let lon = payload.longitude {
            ex.latitude = lat
            ex.longitude = lon
        }
        if let color = payload.color {
            ex.colorR = Int16(color.r)
            ex.colorG = Int16(color.g)
            ex.colorB = Int16(color.b)
        }
        if let data = posterThumbData {
            ex.posterThumbData = data
        }
        ex.admissionFeeRules = payload.admissionFees
        ex.reservationRequired = payload.reservationRequired
        if let schedule = payload.schedule {
            ex.scheduleOpenTime = schedule.openTime
            ex.scheduleCloseTime = schedule.closeTime
            ex.scheduleLastEntryTime = schedule.lastEntryTime
            ex.scheduleClosedWeekdays = schedule.closedWeekdays
            ex.scheduleHolidayHandling = schedule.holidayHandling
            ex.scheduleClosedDateRules = schedule.closedDateRules
            ex.scheduleOpenDateRules = schedule.openDateRules
            ex.scheduleSpecialOpenings = schedule.specialOpenings
        }
        context.insert(ex)
        try? context.save()
        dismiss()
        onComplete()
    }

    @ViewBuilder
    private var posterPreview: some View {
        if let data = posterThumbData, let image = UIImage(data: data) {
            HStack {
                Spacer()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer()
            }
            .padding(.vertical, 4)
        } else if isLoadingPoster {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private func loadPosterThumb() async {
        guard posterThumbData == nil else { return }
        if let base64 = payload.posterThumbBase64, let data = Data(base64Encoded: base64) {
            posterThumbData = data
            return
        }
        guard let urlString = payload.posterThumbURL,
              let url = URL(string: urlString)
        else { return }
        isLoadingPoster = true
        defer { isLoadingPoster = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            posterThumbData = data
        } catch {
            posterThumbData = nil
        }
    }

    private func weekdayLabel(_ weekdays: [String]) -> String {
        let map: [String: String] = [
            "monday": "月",
            "tuesday": "火",
            "wednesday": "水",
            "thursday": "木",
            "friday": "金",
            "saturday": "土",
            "sunday": "日"
        ]
        return weekdays.compactMap { map[$0.lowercased()] }.joined(separator: "・")
    }

    private func holidayHandlingLabel(_ raw: String) -> String {
        switch raw.uppercased() {
        case "NONE":
            return "祝日対応なし"
        case "OPEN_ON_HOLIDAY":
            return "祝日は開館"
        case "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY":
            return "祝日開館・翌平日休館"
        default:
            return raw
        }
    }

    private func dateRuleText(_ rule: DateRuleRecord) -> String {
        switch rule.ruleType {
        case .date:
            return rule.date ?? ""
        case .range:
            guard let start = rule.startDate, let end = rule.endDate else { return "" }
            return "\(start)〜\(end)"
        }
    }

    private func specialOpeningText(_ record: SpecialOpeningRecord) -> String {
        let label: String
        switch record.ruleType {
        case .date:
            label = record.date ?? ""
        case .weekday:
            if let weekday = record.weekday {
                label = "毎週\(weekdayLabel([weekday.rawValue]))"
            } else {
                label = ""
            }
        case .range:
            if let start = record.startDate, let end = record.endDate {
                label = "\(start)〜\(end)"
            } else {
                label = ""
            }
        }
        let time = "\(record.openTime)〜\(record.closeTime)"
        if let last = record.lastEntryTime, !last.isEmpty {
            return "\(label) \(time) 最終入場 \(last)"
        }
        return "\(label) \(time)"
    }
}
