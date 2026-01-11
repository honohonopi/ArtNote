//
//  CatalogPDFImporter.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import Foundation
import PDFKit
import SwiftData

struct CatalogImportResult {
    let createdCount: Int
    let updatedCount: Int
    let estimatedCount: Int?
}

enum CatalogPDFImporter {
    static func importCatalog(
        from url: URL,
        exhibition: Exhibition,
        context: ModelContext
    ) throws -> CatalogImportResult {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }

        guard let document = PDFDocument(url: url) else {
            throw CatalogPDFImportError.invalidPDF
        }
        let rawText = extractText(from: document)
        let entries = parseEntries(from: rawText)
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
            let key = entry.catalogNumber
            let note = noteMap[key] ?? noteMap[entry.displayCatalogNumber ?? ""]
            if let note {
                apply(entry: entry, to: note)
                updated += 1
            } else {
                let newNote = ArtworkNote(
                    exhibitionId: exhibition.id,
                    catalogNumber: entry.catalogNumber,
                    catalogIndex: entry.catalogIndex,
                    displayCatalogNumber: entry.displayCatalogNumber,
                    memo: ""
                )
                apply(entry: entry, to: newNote)
                context.insert(newNote)
                created += 1
            }
        }

        let estimatedCount = estimateTotalCount(from: entries)
        return CatalogImportResult(
            createdCount: created,
            updatedCount: updated,
            estimatedCount: estimatedCount
        )
    }

    private static func extractText(from document: PDFDocument) -> String {
        var lines: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let pageText = page.string
            else { continue }
            lines.append(pageText)
        }
        return lines.joined(separator: "\n")
    }

    private static func parseEntries(from text: String) -> [CatalogEntry] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let pattern = #"^([A-Za-z]*\d+(?:-\d+)?[A-Za-z]?)[\s\.、)]*(.+)?$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        var entries: [RawEntry] = []
        var current: RawEntry?

        for line in lines {
            if let regex,
               let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
                let numberRange = match.range(at: 1)
                let textRange = match.range(at: 2)
                let number = substring(line, range: numberRange)
                let rest = textRange.location != NSNotFound ? substring(line, range: textRange) : ""
                if let current {
                    entries.append(current)
                }
                current = RawEntry(number: number, text: rest)
            } else if var currentEntry = current {
                currentEntry.text = [currentEntry.text, line].filter { !$0.isEmpty }.joined(separator: " ")
                current = currentEntry
            }
        }
        if let current {
            entries.append(current)
        }

        return entries.map { normalizeEntry($0) }
    }

    private static func normalizeEntry(_ entry: RawEntry) -> CatalogEntry {
        let trimmedNumber = entry.number.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedIndex = Int(trimmedNumber.filter(\.isNumber))
        let storedNumber = parsedIndex.map(String.init) ?? trimmedNumber
        let displayNumber = storedNumber == trimmedNumber ? nil : trimmedNumber

        let text = entry.text
            .replacingOccurrences(of: "　", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let separator: String
        if text.contains("／") {
            separator = "／"
        } else if text.contains("/") {
            separator = "/"
        } else {
            separator = ""
        }

        var title: String? = nil
        var artist: String? = nil
        if !separator.isEmpty {
            let parts = text.split(separator: Character(separator), maxSplits: 1)
            title = parts.first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count > 1 {
                artist = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            title = text.isEmpty ? nil : text
        }

        let yearText = extractYearText(from: text)

        return CatalogEntry(
            catalogNumber: storedNumber,
            catalogIndex: parsedIndex,
            displayCatalogNumber: displayNumber,
            title: title,
            artist: artist,
            yearText: yearText,
            material: nil,
            collection: nil
        )
    }

    private static func apply(entry: CatalogEntry, to note: ArtworkNote) {
        if let title = entry.title, note.artworkTitle?.isEmpty ?? true {
            note.artworkTitle = title
        }
        if let artist = entry.artist, note.artist?.isEmpty ?? true {
            note.artist = artist
        }
        if let yearText = entry.yearText, note.yearText?.isEmpty ?? true {
            note.yearText = yearText
        }
        if let material = entry.material, note.material?.isEmpty ?? true {
            note.material = material
        }
        if let collection = entry.collection, note.collection?.isEmpty ?? true {
            note.collection = collection
        }
        if note.catalogIndex == nil {
            note.catalogIndex = entry.catalogIndex
        }
        if note.displayCatalogNumber == nil, let display = entry.displayCatalogNumber {
            note.displayCatalogNumber = display
        }
    }

    private static func estimateTotalCount(from entries: [CatalogEntry]) -> Int? {
        let numeric = entries.compactMap { $0.catalogIndex }
        if let maxValue = numeric.max() {
            return maxValue
        }
        return entries.isEmpty ? nil : entries.count
    }

    private static func substring(_ text: String, range: NSRange) -> String {
        guard let r = Range(range, in: text) else { return "" }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractYearText(from text: String) -> String? {
        let pattern = #"(1[6-9]\d{2}|20\d{2})"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        guard let regex,
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        else { return nil }
        return substring(text, range: match.range(at: 1))
    }
}

private struct RawEntry {
    let number: String
    var text: String
}

private struct CatalogEntry {
    let catalogNumber: String
    let catalogIndex: Int?
    let displayCatalogNumber: String?
    let title: String?
    let artist: String?
    let yearText: String?
    let material: String?
    let collection: String?
}

enum CatalogPDFImportError: LocalizedError {
    case invalidPDF
    case noEntries

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "PDFの読み込みに失敗しました。"
        case .noEntries:
            return "作品リスト情報を見つけられませんでした。"
        }
    }
}
