//
//  DayExhibitionsListView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/18.
//

// 日付別展示一覧
import SwiftUI
import UIKit

struct DayExhibitionsListView: View {
    let date: Date
    let exhibitions: [Exhibition]
    var onSelect: (Exhibition) -> Void = { _ in }   // ← 選択コールバック
    @State private var viewMode: DayViewMode = .exhibitions
    @StateObject private var timelineViewModel = DayTimelineViewModel()

    private var dfHeader: DateFormatter { let f=DateFormatter(); f.locale = .init(identifier:"ja_JP"); f.dateFormat="M月d日（E）"; return f }
    private var dfRange: DateFormatter  { let f=DateFormatter(); f.locale = .init(identifier:"ja_JP"); f.dateFormat="M/d"; return f }

    private enum DayViewMode: String, CaseIterable, Identifiable {
        case exhibitions = "展示"
        case timeline = "タイムライン"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("表示", selection: $viewMode) {
                    ForEach(DayViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if viewMode == .exhibitions {
                    Group {
                        if exhibitions.isEmpty {
                            ContentUnavailableView(
                                "この日に開催中の展示はありません",
                                systemImage: "calendar",
                                description: Text(dfHeader.string(from: date))
                            )
                        } else {
                            List {
                                ForEach(exhibitions, id: \.persistentModelID) { ex in
                                    NavigationLink {
                                        ExhibitionDetailView(exhibition: ex) // ← モーダル内でプッシュ
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            scheduleTag(for: ex)
                                            Text(ex.title).font(.headline)
                                            Text("\(dfRange.string(from: ex.startDate)) 〜 \(dfRange.string(from: ex.endDate))")
                                                .font(.footnote).foregroundStyle(.secondary)
                                            if !ex.venue.isEmpty {
                                                Text(ex.venue).font(.footnote)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .simultaneousGesture(TapGesture().onEnded { onSelect(ex) })
                                }
                            }
                            .listStyle(.insetGrouped)
                        }
                    }
                } else {
                    DayTimelineView(
                        date: date,
                        exhibitions: exhibitions,
                        viewModel: timelineViewModel
                    )
                }
            }
            .navigationTitle(dfHeader.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private func scheduleTag(for exhibition: Exhibition) -> some View {
        let status = ExhibitionScheduleUtils.openingStatus(on: date, exhibition: exhibition)
        switch status {
        case .closed:
            Text("休館日")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 4))
        case let .open(openTime, closeTime, lastEntryTime):
            let themeColor = exhibition.swiftUIColor ?? .blue
            let textColor = readableTextColor(for: themeColor)
            if openTime == "未設定" || closeTime == "未設定" {
                Text("開館時間未設定")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 4))
            } else if let last = lastEntryTime, !last.isEmpty {
                Text("\(openTime)–\(closeTime) / 最終入場 \(last)")
                    .font(.caption)
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(themeColor.opacity(0.85),
                                in: RoundedRectangle(cornerRadius: 4))
            } else {
                Text("\(openTime)–\(closeTime)")
                    .font(.caption)
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(themeColor.opacity(0.85),
                                in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private func readableTextColor(for color: Color) -> Color {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .white
        }
        // Relative luminance for contrast.
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance < 0.6 ? .white : .black
    }
}
