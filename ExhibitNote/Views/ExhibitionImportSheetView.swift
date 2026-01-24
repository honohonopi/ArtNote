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
                        Text(payload.title)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "building.columns")
                            .foregroundStyle(.secondary)
                        Text("会場")
                        Spacer()
                        Text(payload.venue)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text("会期")
                        Spacer()
                        Text("\(formatYMD(payload.startDate)) ~ \(formatYMD(payload.endDate))")
                            .foregroundStyle(.secondary)
                    }
                    if let address = payload.address, !address.isEmpty {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(.secondary)
                            Text("住所")
                            Spacer()
                            Text(address)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let url = payload.url, !url.isEmpty {
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
                if !payload.admissionFees.isEmpty || payload.reservationRequired != nil {
                    Section("入館情報") {
                        let displayFees = sanitizedAdmissionFees(payload.admissionFees)
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
                            if let required = payload.reservationRequired {
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
                if let schedule = payload.schedule {
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
                                    Text(weekdayLabel(schedule.closedWeekdays))
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
                                    Text(holidayHandlingLabel(handling))
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
                                    Text(dateRulesText(schedule.closedDateRules))
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
                                    Text(dateRulesText(schedule.openDateRules))
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
                                            let parts = specialOpeningParts(record)
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
    private var posterPreviewInline: some View {
        if let data = posterThumbData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if isLoadingPoster {
            ProgressView()
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
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

    private func formatYMD(_ value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = raw.split(separator: "-")
        if parts.count == 3 {
            let y = parts[0]
            let m = parts[1].count == 1 ? "0\(parts[1])" : String(parts[1])
            let d = parts[2].count == 1 ? "0\(parts[2])" : String(parts[2])
            return "\(y)/\(m)/\(d)"
        }
        return raw.replacingOccurrences(of: "-", with: "/")
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

    private func dateRulesText(_ rules: [DateRuleRecord]) -> String {
        rules.map { dateRuleText($0) }.joined(separator: "\n")
    }

    private func specialOpeningParts(_ record: SpecialOpeningRecord) -> (main: String, lastEntry: String?) {
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
        let main = "\(label) \(time)".trimmingCharacters(in: .whitespacesAndNewlines)
        let last = record.lastEntryTime?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last, !last.isEmpty {
            return (main, "最終入場 \(last)")
        }
        return (main, nil)
    }

    private func sanitizedAdmissionFees(_ fees: [AdmissionFeeRule]) -> [AdmissionFeeRule] {
        fees.compactMap { fee in
            let label = fee.rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let note = fee.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if label.isEmpty && fee.priceYen == nil && note.isEmpty {
                return nil
            }
            var cleaned = fee
            cleaned.rawLabel = label
            cleaned.note = note.isEmpty ? nil : note
            return cleaned
        }
    }
}
