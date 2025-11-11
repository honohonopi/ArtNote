//
//  ImageStore.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2025/11/08.
//

import UIKit

enum ImageStore {
    static func saveJPEG(_ image: UIImage, quality: CGFloat = 0.85) throws -> String {
        let name = UUID().uuidString + ".jpg"
        let url = try fileURL(for: name)
        let data = image.jpegData(compressionQuality: quality) ?? Data()
        try data.write(to: url, options: .atomic)
        return name
    }

    static func load(_ name: String) -> UIImage? {
        guard let url = try? fileURL(for: name),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(_ name: String) {
        if let url = try? fileURL(for: name) { try? FileManager.default.removeItem(at: url) }
    }

    private static func fileURL(for name: String) throws -> URL {
        let dir = try FileManager.default.url(for: .documentDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)
        return dir.appendingPathComponent(name)
    }
}
