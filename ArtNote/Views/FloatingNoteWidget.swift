//
//  FloatingNoteWidget.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/28.
//

import SwiftUI

struct FloatingNoteWidget: View {
    @EnvironmentObject private var overlay: AppOverlayState
    let mini: AppOverlayState.MinimizedNote

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.pencil")
            VStack(alignment: .leading, spacing: 2) {
                Text(mini.exhibition.title).font(.caption.bold()).lineLimit(1)
                Text("鑑賞モードを再開").font(.caption2).foregroundStyle(.secondary)
            }
            Button {
                overlay.minimized = nil
            } label: {
                Image(systemName: "xmark").font(.caption.bold())
            }.buttonStyle(.plain)
        }
        .padding(10)
        .background(Capsule().fill((mini.exhibition.swiftUIColor ?? .blue).opacity(0.12)))
        .overlay(Capsule().stroke((mini.exhibition.swiftUIColor ?? .blue).opacity(0.35), lineWidth: 1))
        .offset(dragOffset)
        .gesture(DragGesture().onChanged { dragOffset = $0.translation })
        .shadow(radius: 4, y: 2)
        .onTapGesture {
            overlay.restorePayload = mini
            overlay.minimized = nil
        }
    }
}
