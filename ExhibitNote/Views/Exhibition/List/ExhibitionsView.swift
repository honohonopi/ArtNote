//
//  ExhibitionsView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

//  展覧会一覧
import SwiftUI
import SwiftData
import UIKit

struct ExhibitionsView: View {
    @Query(sort: [SortDescriptor(\Exhibition.startDate, order: .forward)])
    private var exhibitions: [Exhibition]

    @State private var vm = ExhibitionListViewModel()
    @State private var showAdd = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Picker("訪問フィルタ", selection: $vm.visitFilter) {
                    ForEach(ExhibitionListViewModel.VisitFilter.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                List {
                    // 一覧
                    ForEach(vm.filteredExhibitions(from: exhibitions)) { ex in
                        NavigationLink(value: ex) {
                            HStack(alignment: .center, spacing: 12) {
                                ExhibitionThumbnail(ex: ex)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(ex.title)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    
                                    if !ex.venue.isEmpty {
                                        Text(ex.venue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Text("\(ex.startDate.ymdString) 〜 \(ex.endDate.ymdString)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer(minLength: 8)
                                
                                // ステータス・バッジ
                                Text(ex.runStatus.badgeText)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ex.runStatus.badgeColor.opacity(0.15), in: Capsule())
                                    .foregroundStyle(ex.runStatus.badgeColor)
                                
                                // 訪問済みアイコン
                                if ex.visited {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                        .imageScale(.medium)
                                        .accessibilityLabel("訪問済み")
                                }
                            }
                            .opacity(ex.endDate < Date() ? 0.6 : 1.0) // 終了済みは少し弱く
                            .contentShape(Rectangle())
                        }
                        // スワイプで訪問切替（右→左）
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                vm.toggleVisited(ex)
                            } label: {
                                Label(ex.visited ? "未訪問に戻す" : "訪問済みにする",
                                      systemImage: ex.visited ? "arrow.uturn.backward" : "checkmark")
                            }
                            .tint(ex.visited ? .orange : .green)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                //                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("展覧会リスト")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.searchText, prompt: "展示名・会場で検索")
            .toolbar {
                // ステータス絞り込みメニュー
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("ステータス", selection: $vm.statusFilter) {
                            Text("すべて").tag(Exhibition.RunStatus?.none)
                            ForEach(Exhibition.RunStatus.allCases) { st in
                                Text(st.label).tag(Exhibition.RunStatus?.some(st))
                            }
                        }
                    } label: {
                        Label("絞り込み", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                
                // 追加ボタン
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("展覧会を追加")
                }
            }
            .sheet(isPresented: $showAdd) {
                ExhibitionFormView()
            }
            .navigationDestination(for: Exhibition.self) { ex in
                ExhibitionDetailView(exhibition: ex)
            }
        }
    }
}

// MARK: - Row 先頭のサムネイル
private struct ExhibitionThumbnail: View {
    let ex: Exhibition

    private var corner: CGFloat { 4 }
    private var size: CGFloat { 44 }

    var body: some View {
        if let data = ex.posterThumbData,
           let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size*1.414)
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .stroke(Color(.quaternaryLabel), lineWidth: 1)
                )
        } else {
            ZStack {
                (ex.swiftUIColor ?? Color.gray).opacity(0.15)
                Image(systemName: "photo.on.rectangle")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: corner))
        }
    }
}
