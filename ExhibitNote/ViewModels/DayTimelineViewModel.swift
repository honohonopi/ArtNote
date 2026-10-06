//
//  DayTimelineViewModel.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI
import Observation
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
@Observable
final class DayTimelineViewModel {
    var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    var events: [DayTimelineEvent] = []
    var isLoading = false
    private(set) var authorizationErrorMessage: String?
    private(set) var isRequestingAccess = false

    private let suggestionService = VisitSuggestionService()
    private var latestRefreshID = UUID()

    func suggestions(
        exhibitions: [Exhibition],
        day: Date,
        includeVisited: Bool,
        now: Date = .now
    ) -> [TimelineSuggestion] {
        // 終日予定は表示のみとし、候補の空き時間計算からは除外する（従来の仕様）。
        let timedEvents = events.filter { !$0.isAllDay }
        return suggestionService.suggestions(
            exhibitions: exhibitions,
            events: timedEvents.map { (start: $0.startDate, end: $0.endDate) },
            day: day,
            includeVisited: includeVisited,
            now: now
        )
    }

    func refresh(for date: Date) {
        let refreshID = UUID()
        latestRefreshID = refreshID
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard hasAccess else {
            events = []
            isLoading = false
            return
        }
        isLoading = true
        authorizationErrorMessage = nil
        Task {
            let calendar = Calendar.japan
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
            let fetched = await Task.detached {
                EventKitService.shared.fetchEvents(start: start, end: end)
            }.value
            // 日付変更や再読み込み後に、古い取得結果で画面を上書きしない。
            guard latestRefreshID == refreshID else { return }
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
        guard !isRequestingAccess else { return }
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if hasAccess {
            refresh(for: date)
            return
        }
        // 拒否・制限済みの場合は再要求せず、View側の案内に任せる。
        guard authorizationStatus == .notDetermined || authorizationStatus == .writeOnly else { return }
        isRequestingAccess = true
        authorizationErrorMessage = nil
        defer { isRequestingAccess = false }
        do {
            _ = try await EventKitService.shared.requestAccess()
            refresh(for: date)
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            authorizationErrorMessage = "カレンダーへのアクセス許可を確認できませんでした。もう一度お試しください。"
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
