//
//  EventKitService.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

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
        let event = EKEvent(eventStore: store)
        event.title = exhibition.title
        event.location = exhibition.venue
        event.startDate = visitDate
        event.endDate = visitDate.addingTimeInterval(durationHours * 3600)
        event.notes = notes ?? exhibition.url?.absoluteString
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
    }
}
