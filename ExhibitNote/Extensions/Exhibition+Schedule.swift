//
//  Exhibition+Schedule.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

extension Exhibition {

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
