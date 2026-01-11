//
//  DayTimelineViewModel.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI
import EventKit
import UIKit

struct DayTimelineEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let color: Color
}

@MainActor
final class DayTimelineViewModel: ObservableObject {
    @Published var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var events: [DayTimelineEvent] = []
    @Published var isLoading = false
    @Published var loadError: String? = nil

    func refresh(for date: Date) {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard hasAccess else { return }
        isLoading = true
        loadError = nil
        Task {
            var calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
            let fetched = await Task.detached {
                EventKitService.shared.fetchEvents(start: start, end: end)
            }.value
            let mapped = fetched.map { event in
                DayTimelineEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "予定",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar.title,
                    color: Color(.systemGray3)
                )
            }
            .sorted { $0.startDate < $1.startDate }
            events = mapped
            isLoading = false
        }
    }

    func requestAccessAndRefresh(for date: Date) async {
        do {
            let granted = try await EventKitService.shared.requestAccess()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            if granted {
                refresh(for: date)
            }
        } catch {
            loadError = "カレンダーの読み込みに失敗しました。"
        }
    }

    var hasAccess: Bool {
        switch authorizationStatus {
        case .authorized, .fullAccess:
            return true
        default:
            return false
        }
    }
}
