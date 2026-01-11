//
//  EventKitService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// カレンダー連携
import EventKit

final class EventKitService {
    static let shared = EventKitService()
    private let store = EKEventStore()
    private init() {}

    @discardableResult
    func requestAccess() async throws -> Bool {
        try await store.requestAccess(to: .event)
    }

    func addVisitEvent(exhibition: Exhibition,
                       visitDate: Date,
                       durationHours: Double = 2,
                       notes: String? = nil) throws {
        let endDate = visitDate.addingTimeInterval(durationHours * 3600)
        try addVisitEvent(exhibition: exhibition, startDate: visitDate, endDate: endDate, notes: notes)
    }

    func addVisitEvent(exhibition: Exhibition,
                       startDate: Date,
                       endDate: Date,
                       notes: String? = nil) throws {
        let event = EKEvent(eventStore: store)
        event.title = exhibition.title
        event.location = exhibition.venue
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes ?? exhibition.url?.absoluteString
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
    }

    func fetchEvents(start: Date, end: Date) -> [EKEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
    }
}
