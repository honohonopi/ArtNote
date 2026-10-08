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
    private let settingsStore = SettingsStore.shared
    let date: Date
    let exhibitions: [Exhibition]
    var viewModel: DayTimelineViewModel
    @State private var showSuggestionActions = false
    @State private var selectedSuggestion: TimelineSuggestion?
    @State private var addVisitTarget: AddVisitEventTarget?
    @State private var detailTarget: DetailNavigationTarget?

    private var dfTime: DateFormatter {
        let f = DateFormatter.japanese()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f
    }

    var body: some View {
        let includeVisited = settingsStore.includeVisitedSuggestions
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasAccess {
                // 開いたままでも、時間の経過に合わせて今日の候補を更新する。
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    timelineContent(now: timeline.date, includeVisited: includeVisited)
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

    private func timelineContent(now: Date, includeVisited: Bool) -> some View {
        let allDayEvents = viewModel.events.filter { $0.isAllDay }
        let timedEvents = viewModel.events.filter { !$0.isAllDay }
        let suggestions = viewModel.suggestions(
            exhibitions: exhibitions,
            day: date,
            includeVisited: includeVisited,
            now: now
        )
        let layoutBuilder = DayTimelineLayoutBuilder(day: date)
        let layout = layoutBuilder.build(events: timedEvents, suggestions: suggestions)
        let metrics = layoutBuilder.metrics

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
                    let carouselCardWidth = layoutBuilder.itemWidth(in: proxy.size.width, columns: 2)
                    ZStack(alignment: .topLeading) {
                        hourGrid(metrics: metrics)
                        ForEach(layout.suggestionClusters) { cluster in
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
                                                    height: item.height
                                                )
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    selectedSuggestion = item.suggestion
                                                    showSuggestionActions = true
                                                }
                                                .offset(
                                                    x: layoutBuilder.carouselXOffset(
                                                        column: item.column,
                                                        cardWidth: carouselCardWidth
                                                    ),
                                                    y: item.relativeYOffset
                                                )
                                        }
                                    }
                                    .frame(
                                        width: layoutBuilder.carouselContentWidth(
                                            columns: cluster.columnCount,
                                            cardWidth: carouselCardWidth
                                        ),
                                        height: cluster.height,
                                        alignment: .topLeading
                                    )
                                }
                                .padding(.leading, metrics.timeColumnWidth + metrics.timeToEventSpacing)
                                .padding(.trailing, metrics.suggestionCarouselPadding)
                                .frame(width: proxy.size.width,
                                       height: cluster.height,
                                       alignment: .leading)
                                .offset(y: cluster.yOffset)
                            } else {
                                ForEach(cluster.items) { item in
                                    SuggestionBlockView(suggestion: item.suggestion, badgeText: nil)
                                        .frame(
                                            width: layoutBuilder.itemWidth(
                                                in: proxy.size.width,
                                                columns: item.columnCount
                                            ),
                                            height: item.height
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedSuggestion = item.suggestion
                                            showSuggestionActions = true
                                        }
                                        .offset(
                                            x: metrics.timeColumnWidth + metrics.timeToEventSpacing
                                                + layoutBuilder.itemXOffset(
                                                    in: proxy.size.width,
                                                    column: item.column,
                                                    columns: item.columnCount
                                                ),
                                            y: item.yOffset
                                        )
                                }
                            }
                        }
                        ForEach(layout.events) { item in
                            DayTimelineEventBlock(
                                event: item.event,
                                timeText: timeText(for: item.event)
                            )
                            .frame(
                                width: layoutBuilder.itemWidth(in: proxy.size.width, columns: item.columnCount),
                                height: item.height
                            )
                            .offset(
                                x: metrics.timeColumnWidth + metrics.timeToEventSpacing
                                    + layoutBuilder.itemXOffset(
                                        in: proxy.size.width,
                                        column: item.column,
                                        columns: item.columnCount
                                    ),
                                y: item.yOffset
                            )
                        }
                    }
                    .padding(.horizontal, metrics.horizontalPadding)
                    .frame(height: metrics.dayHeight)
                }
                .frame(height: metrics.dayHeight)
            }
            .padding(.vertical, 12)
        }
    }

    private func hourGrid(metrics: DayTimelineLayoutBuilder.Metrics) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: metrics.timeToEventSpacing) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: metrics.timeColumnWidth, alignment: .trailing)
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 1)
                }
                .frame(height: metrics.hourHeight, alignment: .top)
            }
        }
    }

    private func timeTextRange(for suggestion: TimelineSuggestion) -> String {
        "\(dfTime.string(from: suggestion.availableStart))–\(dfTime.string(from: suggestion.availableEnd))"
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
        let f = DateFormatter.japanese()
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
