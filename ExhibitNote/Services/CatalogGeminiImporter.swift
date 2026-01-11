//
//  CatalogGeminiImporter.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import Foundation
import PDFKit
import SwiftData
import GoogleGenerativeAI
import UIKit

struct GeminiCatalogImportResult {
    let createdCount: Int
    let updatedCount: Int
    let estimatedCount: Int?
}

enum CatalogGeminiImporter {
    private static let maxPages = 8

    static func importCatalog(
        from url: URL,
        exhibition: Exhibition,
        context: ModelContext
    ) async throws -> GeminiCatalogImportResult {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }

        guard let document = PDFDocument(url: url) else {
            throw CatalogPDFImportError.invalidPDF
        }
        let model = GenerativeModel(name: "gemini-2.5-flash-lite", apiKey: APIKey.default)

        var entries: [GeminiCatalogEntry] = []
        let pageCount = min(document.pageCount, maxPages)
        for index in 0..<pageCount {
            guard let page = document.page(at: index) else { continue }
            let image = renderImage(from: page)
            let response = try await model.generateContent(GeminiPrompts.catalogList, image)
            let text = response.text ?? ""
            print("🤖 AI raw response (catalog page \(index + 1)): \(text)")
            guard let json = JSONSnippetExtractor.extractFirstJSON(from: text),
                  let data = json.data(using: .utf8) else {
                continue
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let payload = try decoder.decode(GeminiCatalogResponse.self, from: data)
            entries.append(contentsOf: payload.catalogEntries ?? [])
        }

        if entries.isEmpty {
            throw CatalogPDFImportError.noEntries
        }

        let exId = exhibition.id
        let fetch = FetchDescriptor<ArtworkNote>(
            predicate: #Predicate { $0.exhibitionId == exId }
        )
        let existing = try context.fetch(fetch)
        var noteMap: [String: ArtworkNote] = [:]
        existing.forEach { note in
            noteMap[note.catalogNumber] = note
            if let display = note.displayCatalogNumber, !display.isEmpty {
                noteMap[display] = note
            }
        }

        var created = 0
        var updated = 0

        for entry in entries {
            let rawNumber = entry.catalogNumber?.trimmed ?? ""
            let displayNumber = (entry.displayCatalogNumber?.trimmed).flatMap { $0.isEmpty ? nil : $0 }
                ?? (rawNumber.isEmpty ? nil : rawNumber)
            let numericFromRaw = rawNumber.filter { $0.isNumber }
            let numericFromDisplay = displayNumber?.filter { $0.isNumber } ?? ""
            let numericString = !numericFromRaw.isEmpty ? numericFromRaw : numericFromDisplay
            let catalogIndex = numericString.isEmpty ? nil : Int(numericString)
            let storedNumber = numericString.isEmpty ? (rawNumber.isEmpty ? (displayNumber ?? "") : rawNumber) : numericString
            guard !storedNumber.isEmpty else { continue }
            let note = noteMap[storedNumber] ?? (displayNumber != nil ? noteMap[displayNumber ?? ""] : nil)
            if let note {
                apply(entry: entry, to: note, catalogIndex: catalogIndex, displayCatalogNumber: displayNumber)
                updated += 1
            } else {
                let newNote = ArtworkNote(
                    exhibitionId: exhibition.id,
                    catalogNumber: storedNumber,
                    catalogIndex: catalogIndex,
                    displayCatalogNumber: displayNumber,
                    memo: ""
                )
                apply(entry: entry, to: newNote, catalogIndex: catalogIndex, displayCatalogNumber: displayNumber)
                context.insert(newNote)
                created += 1
            }
        }

        let estimatedCount = entries.compactMap { entry -> Int? in
            let rawNumber = entry.catalogNumber?.trimmed ?? ""
            let displayNumber = (entry.displayCatalogNumber?.trimmed).flatMap { $0.isEmpty ? nil : $0 }
                ?? (rawNumber.isEmpty ? nil : rawNumber)
            let numericFromRaw = rawNumber.filter { $0.isNumber }
            let numericFromDisplay = displayNumber?.filter { $0.isNumber } ?? ""
            let numericString = !numericFromRaw.isEmpty ? numericFromRaw : numericFromDisplay
            return numericString.isEmpty ? nil : Int(numericString)
        }.max()

        return GeminiCatalogImportResult(
            createdCount: created,
            updatedCount: updated,
            estimatedCount: estimatedCount
        )
    }

    private static func renderImage(from page: PDFPage) -> UIImage {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: pageRect.width * scale,
                                                            height: pageRect.height * scale))
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
            ctx.cgContext.translateBy(x: 0, y: renderer.format.bounds.size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    private static func apply(
        entry: GeminiCatalogEntry,
        to note: ArtworkNote,
        catalogIndex: Int?,
        displayCatalogNumber: String?
    ) {
        if let title = entry.title?.trimmed, !title.isEmpty {
            note.artworkTitle = title
        }
        if let artist = entry.artist?.trimmed, !artist.isEmpty {
            note.artist = artist
        }
        if let yearText = entry.yearText?.trimmed, !yearText.isEmpty {
            note.yearText = yearText
        }
        if let material = entry.material?.trimmed, !material.isEmpty {
            note.material = material
        }
        if let collection = entry.collection?.trimmed, !collection.isEmpty {
            note.collection = collection
        }
        if let catalogIndex {
            note.catalogIndex = catalogIndex
        }
        if let displayCatalogNumber, !displayCatalogNumber.isEmpty {
            note.displayCatalogNumber = displayCatalogNumber
        }
    }
}

private struct GeminiCatalogResponse: Decodable {
    let catalogEntries: [GeminiCatalogEntry]?
}

private struct GeminiCatalogEntry: Decodable {
    let catalogNumber: String?
    let displayCatalogNumber: String?
    let title: String?
    let artist: String?
    let yearText: String?
    let material: String?
    let collection: String?
}
