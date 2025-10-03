//
//  ExhibitionsView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/03.
//

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
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ex.title).font(.body.weight(.semibold))
                            Text(ex.venue).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(ex.startDate, style: .date) - \(ex.endDate, style: .date)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
