//
//  ExhibitionsView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

// 展覧会一覧
import SwiftUI
import SwiftData

struct ExhibitionsView: View {
    @Query private var exhibitions: [Exhibition]
    @State private var showAdd = false
    
    init() {
        _exhibitions = Query(sort: [SortDescriptor(\.startDate, order: .forward)])
    }
    
    var body: some View {
        NavigationStack {
            List(exhibitions) { ex in
                NavigationLink(value: ex) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ex.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(ex.venue)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(ex.startDate.ymdString) 〜 \(ex.endDate.ymdString)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .opacity(ex.endDate < Date() ? 0.5 : 1.0)
                }
            }
            .navigationTitle("Exhibitions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { ExhibitionFormView() }
            .navigationDestination(for: Exhibition.self) { ex in
                ExhibitionDetailView(exhibition: ex)
            }
        }
    }
}
