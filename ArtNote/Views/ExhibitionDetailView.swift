//
//  ExhibitionDetailView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

import SwiftUI
import SwiftData

struct ExhibitionDetailView: View {
    let exhibition: Exhibition
    @Environment(\.modelContext) private var context
    
    @Query private var notes: [ArtworkNote]
    @State private var showQuick = false
    
    
    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        let exId = exhibition.id
        _notes = Query(filter: #Predicate<ArtworkNote> { n in n.exhibitionId == exId },
                       sort: [SortDescriptor(\.catalogNumber, order: .forward)])
    }
    
    var body: some View {
        List {
            Section("") {
                HStack {
                    VStack(alignment: .leading) {
                        Text(exhibition.title).font(.title3).bold()
                        Text("\(exhibition.venue) / 〜 \(exhibition.endDate, style: .date)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showQuick = true } label: {
                        Label("鑑賞モード", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Section("メモ（\(notes.count)）") {
                ForEach(notes) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("#\(n.catalogNumber)").font(.caption).monospaced()
                            Spacer()
                            Text(n.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(n.memo).font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("詳細")
        .sheet(isPresented: $showQuick) {
            CardPagingNoteView(exhibition: exhibition)
                .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(items: [exhibition.title, exhibition.venue]) { Image(systemName: "square.and.arrow.up") }
            }
        }
    }
}
