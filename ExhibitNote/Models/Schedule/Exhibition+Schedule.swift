//
//  Exhibition+Schedule.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

extension Exhibition {

    // MARK: - Closed/Open Date Rules (Data <-> [DateRuleRecord])

    var scheduleClosedDateRules: [DateRuleRecord] {
        get {
            if let data = scheduleClosedDateRulesData,
               let decoded = try? JSONDecoder().decode([DateRuleRecord].self, from: data) {
                return decoded
            }
            return scheduleClosedDates.map { date in
                DateRuleRecord.forDate(DateRuleRecordDateFormatter.formatter.string(from: date))
            }
        }
        set {
            scheduleClosedDateRulesData = try? JSONEncoder().encode(newValue)
            if !newValue.isEmpty {
                scheduleClosedDates = []
            }
        }
    }

    var scheduleOpenDateRules: [DateRuleRecord] {
        get {
            if let data = scheduleOpenDateRulesData,
               let decoded = try? JSONDecoder().decode([DateRuleRecord].self, from: data) {
                return decoded
            }
            return scheduleOpenDates.map { date in
                DateRuleRecord.forDate(DateRuleRecordDateFormatter.formatter.string(from: date))
            }
        }
        set {
            scheduleOpenDateRulesData = try? JSONEncoder().encode(newValue)
            if !newValue.isEmpty {
                scheduleOpenDates = []
            }
        }
    }

    // MARK: - Special Openings (Data <-> [SpecialOpeningRecord])

    var scheduleSpecialOpenings: [SpecialOpeningRecord] {
        get {
            guard let data = scheduleSpecialOpeningsData else { return [] }
            return (try? JSONDecoder().decode([SpecialOpeningRecord].self, from: data)) ?? []
        }
        set {
            scheduleSpecialOpeningsData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Helpers (optional)

    func upsertSpecialOpening(_ record: SpecialOpeningRecord) {
        var items = scheduleSpecialOpenings
        if let idx = items.firstIndex(where: { $0.id == record.id }) {
            items[idx] = record
        } else {
            items.append(record)
        }
        scheduleSpecialOpenings = items
    }

    func removeSpecialOpening(id: String) {
        scheduleSpecialOpenings = scheduleSpecialOpenings.filter { $0.id != id }
    }
}

private enum DateRuleRecordDateFormatter {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
