//
//  DayTimelineView.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI
import EventKit
import UIKit

struct DayTimelineView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    let date: Date
    let exhibitions: [Exhibition]
    @ObservedObject var viewModel: DayTimelineViewModel
    @State private var showSuggestionActions = false
    @State private var selectedSuggestion: TimelineSuggestion?
    @State private var addVisitTarget: AddVisitEventTarget?
    @State private var detailTarget: DetailNavigationTarget?

    private let timeColumnWidth: CGFloat = 44
    private let hourHeight: CGFloat = 60
    private let columnSpacing: CGFloat = 6
    private let horizontalPadding: CGFloat = 8
    private let timeToEventSpacing: CGFloat = 8
    private let suggestionCarouselPadding: CGFloat = 16

    private var dfTime: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasAccess {
                // 開いたままでも、時間の経過に合わせて今日の候補を更新する。
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    timelineContent(now: timeline.date)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(accessMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if viewModel.authorizationStatus == .notDetermined || viewModel.authorizationStatus == .writeOnly {
                        if let message = viewModel.authorizationErrorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Button(viewModel.authorizationErrorMessage == nil ? "カレンダーへのアクセスを許可" : "もう一度試す") {
                            Task { await viewModel.requestAccessAndRefresh(for: date) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isRequestingAccess)
                    } else if viewModel.authorizationStatus == .denied {
                        Button("設定アプリを開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationDestination(item: $detailTarget) { target in
            ExhibitionDetailView(exhibition: target.exhibition)
        }
        .navigationDestination(item: $addVisitTarget) { target in
            AddVisitEventSheetView(
                exhibition: target.exhibition,
                initialStart: target.availableStart,
                availableEnd: target.availableEnd
            )
        }
        .confirmationDialog("提案", isPresented: $showSuggestionActions, presenting: selectedSuggestion) { suggestion in
            Button("詳細を見る") {
                detailTarget = DetailNavigationTarget(exhibition: suggestion.exhibition)
            }
            Button("予定に追加") {
                addVisitTarget = AddVisitEventTarget(
                    exhibition: suggestion.exhibition,
                    availableStart: suggestion.availableStart,
                    availableEnd: suggestion.availableEnd
                )
            }
            Button("キャンセル", role: .cancel) {}
        } message: { suggestion in
            Text("行ける時間 \(timeTextRange(for: suggestion))")
        }
        .onAppear {
            viewModel.refresh(for: date)
        }
        .onChange(of: date) { _, newValue in
            viewModel.refresh(for: newValue)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refresh(for: date)
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged).receive(on: RunLoop.main)) { _ in
            guard scenePhase == .active else { return }
            viewModel.refresh(for: date)
        }
    }

    private func timeText(for event: DayTimelineEvent) -> String {
        if event.isAllDay {
            return "終日"
        }
        return "\(dfTime.string(from: event.startDate))–\(dfTime.string(from: event.endDate))"
    }

    private var accessMessage: String {
        switch viewModel.authorizationStatus {
        case .denied:
            return "カレンダーへのアクセスが許可されていません。設定アプリで、このアプリのカレンダーへのフルアクセスを許可してください。"
        case .restricted:
            return "端末の機能制限により、カレンダーを利用できません。スクリーンタイムや管理者による制限を確認してください。"
        case .notDetermined:
            return "予定と空き時間を表示するため、カレンダーへのアクセスが必要です。"
        case .writeOnly:
            return "現在は予定の追加のみ許可されています。予定と空き時間を表示するには、フルアクセスが必要です。"
        default:
            return "カレンダーへのアクセスが許可されていません"
        }
    }

    private func timelineContent(now: Date) -> some View {
        let allDayEvents = viewModel.events.filter { $0.isAllDay }
        let timedEvents = viewModel.events.filter { !$0.isAllDay }
        let layoutItems = layoutEvents(timedEvents)
        let suggestions = viewModel.suggestions(
            exhibitions: exhibitions,
            day: date,
            now: now
        )
        let suggestionClusters = layoutSuggestionClusters(suggestions)

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !allDayEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("終日")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(allDayEvents) { event in
                            DayTimelineEventRow(
                                event: event,
                                timeText: "終日"
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }

                GeometryReader { proxy in
                    let carouselCardWidth = itemWidth(in: proxy.size.width, columns: 2)
                    ZStack(alignment: .topLeading) {
                        hourGrid
                        ForEach(suggestionClusters) { cluster in
                            if cluster.columnCount >= 3 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    ZStack(alignment: .topLeading) {
                                        ForEach(Array(cluster.items.enumerated()), id: \.element.id) { index, item in
                                            SuggestionBlockView(
                                                suggestion: item.suggestion,
                                                badgeText: "\(index + 1)/\(cluster.items.count)"
                                            )
                                                .frame(
                                                    width: carouselCardWidth,
                                                    height: suggestionHeight(item.suggestion)
                                                )
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    selectedSuggestion = item.suggestion
                                                    showSuggestionActions = true
                                                }
                                                .offset(
                                                    x: suggestionCarouselXOffset(column: item.column,
                                                                                 cardWidth: carouselCardWidth),
                                                    y: suggestionYOffsetRelative(item.suggestion,
                                                                                 clusterStart: cluster.start)
                                                )
                                        }
                                    }
                                    .frame(
                                        width: suggestionCarouselContentWidth(columns: cluster.columnCount,
                                                                             cardWidth: carouselCardWidth),
                                        height: suggestionClusterHeight(cluster),
                                        alignment: .topLeading
                                    )
                                }
                                .padding(.leading, timeColumnWidth + timeToEventSpacing)
                                .padding(.trailing, suggestionCarouselPadding)
                                .frame(width: proxy.size.width,
                                       height: suggestionClusterHeight(cluster),
                                       alignment: .leading)
                                .offset(y: suggestionClusterYOffset(cluster))
                            } else {
                                ForEach(cluster.items) { item in
                                    SuggestionBlockView(suggestion: item.suggestion, badgeText: nil)
                                        .frame(
                                            width: itemWidth(in: proxy.size.width, columns: item.columnCount),
                                            height: suggestionHeight(item.suggestion)
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedSuggestion = item.suggestion
                                            showSuggestionActions = true
                                        }
                                        .offset(
                                            x: timeColumnWidth + timeToEventSpacing
                                                + itemXOffset(in: proxy.size.width,
                                                              column: item.column,
                                                              columns: item.columnCount),
                                            y: suggestionYOffset(item.suggestion)
                                        )
                                }
                            }
                        }
                        ForEach(layoutItems) { item in
                            DayTimelineEventBlock(
                                event: item.event,
                                timeText: timeText(for: item.event)
                            )
                            .frame(width: itemWidth(in: proxy.size.width, columns: item.columnCount),
                                   height: max(24, itemHeight(item.event)))
                            .offset(x: timeColumnWidth + timeToEventSpacing + itemXOffset(in: proxy.size.width, column: item.column, columns: item.columnCount),
                                    y: itemYOffset(item.event))
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .frame(height: hourHeight * 24)
                }
                .frame(height: hourHeight * 24)
            }
            .padding(.vertical, 12)
        }
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: timeToEventSpacing) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: timeColumnWidth, alignment: .trailing)
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 1)
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
    }

    private func itemYOffset(_ event: DayTimelineEvent) -> CGFloat {
        let start = max(event.startDate, dayStart)
        let minutes = minutesFromStart(of: start)
        return CGFloat(minutes / 60.0) * hourHeight
    }

    private func itemHeight(_ event: DayTimelineEvent) -> CGFloat {
        let start = max(event.startDate, dayStart)
        let end = min(event.endDate, dayEnd)
        let minutes = max(30.0, minutesBetween(start: start, end: end))
        return CGFloat(minutes / 60.0) * hourHeight
    }

    private func itemWidth(in totalWidth: CGFloat, columns: Int) -> CGFloat {
        let contentWidth = max(0, totalWidth - timeColumnWidth - timeToEventSpacing - horizontalPadding * 2)
        let spacing = CGFloat(max(columns - 1, 0)) * columnSpacing
        return (contentWidth - spacing) / CGFloat(max(columns, 1))
    }

    private func itemXOffset(in totalWidth: CGFloat, column: Int, columns: Int) -> CGFloat {
        let width = itemWidth(in: totalWidth, columns: columns)
        return CGFloat(column) * (width + columnSpacing)
    }

    private func suggestionCarouselXOffset(column: Int, cardWidth: CGFloat) -> CGFloat {
        CGFloat(column) * (cardWidth + columnSpacing)
    }

    private func suggestionCarouselContentWidth(columns: Int, cardWidth: CGFloat) -> CGFloat {
        guard columns > 0 else { return 0 }
        let cards = CGFloat(columns) * cardWidth
        let spacing = CGFloat(max(columns - 1, 0)) * columnSpacing
        return cards + spacing
    }

    private func suggestionClusterYOffset(_ cluster: SuggestionCluster) -> CGFloat {
        let minutes = minutesFromStart(of: cluster.start)
        return CGFloat(minutes / 60.0) * hourHeight
    }

    private func suggestionClusterHeight(_ cluster: SuggestionCluster) -> CGFloat {
        let minutes = max(0, minutesBetween(start: cluster.start, end: cluster.end))
        return CGFloat(minutes / 60.0) * hourHeight
    }

    private func suggestionYOffset(_ suggestion: TimelineSuggestion) -> CGFloat {
        let start = max(suggestion.availableStart, dayStart)
        let minutes = minutesFromStart(of: start)
        return CGFloat(minutes / 60.0) * hourHeight
    }

    private func suggestionYOffsetRelative(
        _ suggestion: TimelineSuggestion,
        clusterStart: Date
    ) -> CGFloat {
        let start = max(suggestion.availableStart, clusterStart)
        let minutes = max(0, start.timeIntervalSince(clusterStart) / 60.0)
        return CGFloat(minutes / 60.0) * hourHeight
    }

    private func suggestionHeight(_ suggestion: TimelineSuggestion) -> CGFloat {
        let start = max(suggestion.availableStart, dayStart)
        let end = min(suggestion.availableEnd, dayEnd)
        let minutes = max(0, minutesBetween(start: start, end: end))
        return CGFloat(minutes / 60.0) * hourHeight
    }

    private func minutesFromStart(of date: Date) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hours = Double(components.hour ?? 0)
        let minutes = Double(components.minute ?? 0)
        return max(0, hours * 60 + minutes)
    }

    private func minutesBetween(start: Date, end: Date) -> Double {
        max(0, end.timeIntervalSince(start) / 60.0)
    }

    private var dayStart: Date {
        Calendar.current.startOfDay(for: date)
    }

    private var dayEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date
    }

    private func timeTextRange(for suggestion: TimelineSuggestion) -> String {
        "\(dfTime.string(from: suggestion.availableStart))–\(dfTime.string(from: suggestion.availableEnd))"
    }


    private func layoutEvents(_ events: [DayTimelineEvent]) -> [EventLayoutItem] {
        TimelineLayout.clusters(for: events, start: \.startDate, end: \.endDate).flatMap { cluster in
            cluster.items.map { item in
                EventLayoutItem(event: item.value, column: item.column, columnCount: cluster.columnCount)
            }
        }
    }

    private func layoutSuggestionClusters(_ suggestions: [TimelineSuggestion]) -> [SuggestionCluster] {
        TimelineLayout.clusters(for: suggestions, start: \.availableStart, end: \.availableEnd).map { cluster in
            SuggestionCluster(
                items: cluster.items.map { item in
                    SuggestionLayoutItem(suggestion: item.value, column: item.column, columnCount: cluster.columnCount)
                },
                columnCount: cluster.columnCount,
                start: cluster.start,
                end: cluster.end
            )
        }
    }

}

private struct DayTimelineEventRow: View {
    let event: DayTimelineEvent
    let timeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(timeText)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Circle()
                    .fill(event.color)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline)
                    Text(event.calendarTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DetailNavigationTarget: Identifiable, Hashable {
    let exhibition: Exhibition

    var id: String { exhibition.id }

    func hash(into hasher: inout Hasher) {
        hasher.combine(exhibition.id)
    }

    static func == (lhs: DetailNavigationTarget, rhs: DetailNavigationTarget) -> Bool {
        lhs.exhibition.id == rhs.exhibition.id
    }
}

private struct AddVisitEventTarget: Identifiable, Hashable {
    let exhibition: Exhibition
    let availableStart: Date
    let availableEnd: Date

    var id: String {
        let start = Int(availableStart.timeIntervalSince1970)
        let end = Int(availableEnd.timeIntervalSince1970)
        return "\(exhibition.id)-\(start)-\(end)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AddVisitEventTarget, rhs: AddVisitEventTarget) -> Bool {
        lhs.id == rhs.id
    }
}

private struct SuggestionBlockView: View {
    let suggestion: TimelineSuggestion
    let badgeText: String?

    private var dfTime: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f
    }

    var body: some View {
        let theme = suggestion.exhibition.swiftUIColor ?? .blue
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Text("提案")
                    .font(.caption2)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(theme.opacity(0.15), in: Capsule())
                    .foregroundStyle(theme)
                if suggestion.exhibition.visited {
                    Text("訪問済み")
                        .font(.caption2)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Color(.systemGray5), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let badgeText {
                    Text(badgeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(suggestion.exhibition.title)
                .font(.headline)
                .lineLimit(2)
            if !suggestion.exhibition.venue.isEmpty {
                Text(suggestion.exhibition.venue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text("行ける時間 \(timeRangeText())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.opacity(0.5), lineWidth: 1)
        )
        .padding(1)
    }

    private func timeRangeText() -> String {
        let start = dfTime.string(from: suggestion.availableStart)
        let end = dfTime.string(from: suggestion.availableEnd)
        return "\(start)–\(end)"
    }
}

private struct SuggestionLayoutItem: Identifiable {
    let suggestion: TimelineSuggestion
    let column: Int
    let columnCount: Int

    var id: String { suggestion.id }
}

private struct SuggestionCluster: Identifiable {
    let items: [SuggestionLayoutItem]
    let columnCount: Int
    let start: Date
    let end: Date

    var id: String {
        let startValue = Int(start.timeIntervalSince1970)
        let endValue = Int(end.timeIntervalSince1970)
        return "\(startValue)-\(endValue)-\(items.count)"
    }
}

private struct DayTimelineEventBlock: View {
    let event: DayTimelineEvent
    let timeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timeText)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(event.title)
                .font(.caption)
                .lineLimit(2)
            Text(event.calendarTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(event.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(event.color.opacity(0.6), lineWidth: 1)
        )
        .padding(1)
    }
}

private struct EventLayoutItem: Identifiable {
    let event: DayTimelineEvent
    let column: Int
    let columnCount: Int

    var id: String { event.id }
}
