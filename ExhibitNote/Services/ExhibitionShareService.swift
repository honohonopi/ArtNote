//
//  ExhibitionShareService.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import Foundation
import UIKit

#if canImport(Network)
import Network
#endif

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseStorage)
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
#endif

struct ExhibitionSharePayload: Codable, Identifiable {
    struct RGB: Codable {
        let r: Int
        let g: Int
        let b: Int
    }

    struct Schedule: Codable {
        let openTime: String?
        let closeTime: String?
        let lastEntryTime: String?
        let closedWeekdays: [String]
        let holidayHandling: String?
        let closedDateRules: [DateRuleRecord]
        let openDateRules: [DateRuleRecord]
        let specialOpenings: [SpecialOpeningRecord]
    }

    let id: String
    let title: String
    let venue: String
    let startDate: String
    let endDate: String
    let address: String?
    let url: String?
    let latitude: Double?
    let longitude: Double?
    let color: RGB?
    let posterThumbBase64: String?
    let posterThumbURL: String?
    let admissionFees: [AdmissionFeeRule]
    let reservationRequired: Bool?
    let schedule: Schedule?
}

enum ExhibitionShareService {
    static let host = "exhibitnote.netlify.app"
    static let path = "/share/exhibition"
    static let customScheme = "exhibitnote"
    static let maxShareURLLength = 3000

    enum ShareError: Error {
        case tooLong
        case unavailable
    }

    static func makeShareURL(for exhibition: Exhibition) async -> Result<URL, ShareError> {
        let isOnline = await isNetworkAvailable()
        if isOnline, let url = await makeRemoteShareURL(for: exhibition) {
            return validateShareURL(url)
        }
        if let legacy = makeLegacyShareURL(for: exhibition, includePoster: false) {
            return validateShareURL(legacy)
        }
        return .failure(.unavailable)
    }

    static func resolvePayload(from url: URL) async -> ExhibitionSharePayload? {
        if url.isFileURL, let payload = decodeShareFile(url) {
            return payload
        }
        let normalized = normalizeShareURL(url)
        if let payload = decodeLegacy(normalized) {
            return payload
        }
        guard let shareId = shareID(from: normalized) else { return nil }
        return await fetchRemotePayload(id: shareId)
    }

    private static func makeLegacyShareURL(for exhibition: Exhibition, includePoster: Bool) -> URL? {
        let payload = ExhibitionSharePayload(
            id: exhibition.id,
            title: exhibition.title,
            venue: exhibition.venue,
            startDate: Self.ymdString(exhibition.startDate),
            endDate: Self.ymdString(exhibition.endDate),
            address: exhibition.address,
            url: exhibition.url?.absoluteString,
            latitude: exhibition.latitude,
            longitude: exhibition.longitude,
            color: shareColor(from: exhibition),
            posterThumbBase64: includePoster ? posterThumbBase64(from: exhibition) : nil,
            posterThumbURL: nil,
            admissionFees: exhibition.admissionFeeRules,
            reservationRequired: exhibition.reservationRequired,
            schedule: shareSchedule(from: exhibition)
        )
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        let token = base64URLEncode(data)
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = host
        comps.path = path
        comps.queryItems = [URLQueryItem(name: "data", value: token)]
        return comps.url
    }

    private static func decodeLegacy(_ url: URL) -> ExhibitionSharePayload? {
        guard url.host == host, url.path == path else { return nil }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = comps.queryItems?.first(where: { $0.name == "data" })?.value,
              let data = base64URLDecode(token)
        else { return nil }
        return try? JSONDecoder().decode(ExhibitionSharePayload.self, from: data)
    }

    private static func shareID(from url: URL) -> String? {
        guard url.host == host, url.path == path else { return nil }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = comps.queryItems?.first(where: { $0.name == "id" })?.value,
              !value.isEmpty
        else { return nil }
        return value
    }

    private static func normalizeShareURL(_ url: URL) -> URL {
        guard url.scheme == customScheme else { return url }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var normalized = URLComponents()
        normalized.scheme = "https"
        normalized.host = host
        if url.host == "share", url.path == "/exhibition" {
            normalized.path = path
        } else if url.path.hasPrefix(path) {
            normalized.path = url.path
        } else if url.host == "share" {
            normalized.path = "/share" + url.path
        } else {
            normalized.path = path
        }
        normalized.queryItems = comps?.queryItems
        return normalized.url ?? url
    }

    private static func validateShareURL(_ url: URL) -> Result<URL, ShareError> {
        if url.absoluteString.count <= maxShareURLLength {
            return .success(url)
        }
        return .failure(.tooLong)
    }

    static func makeAirDropShareFile(for exhibition: Exhibition) -> URL? {
        let payload = ExhibitionSharePayload(
            id: exhibition.id,
            title: exhibition.title,
            venue: exhibition.venue,
            startDate: Self.ymdString(exhibition.startDate),
            endDate: Self.ymdString(exhibition.endDate),
            address: exhibition.address,
            url: exhibition.url?.absoluteString,
            latitude: exhibition.latitude,
            longitude: exhibition.longitude,
            color: shareColor(from: exhibition),
            posterThumbBase64: posterThumbBase64ForFile(from: exhibition),
            posterThumbURL: nil,
            admissionFees: exhibition.admissionFeeRules,
            reservationRequired: exhibition.reservationRequired,
            schedule: shareSchedule(from: exhibition)
        )
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        let filename = "exhibition-\(UUID().uuidString).exhibitnote"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }

    private static func decodeShareFile(_ url: URL) -> ExhibitionSharePayload? {
        guard url.pathExtension.lowercased() == "exhibitnote" else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ExhibitionSharePayload.self, from: data)
    }

    private static func posterThumbBase64ForFile(from exhibition: Exhibition) -> String? {
        guard let data = exhibition.posterThumbData, !data.isEmpty else { return nil }
        return data.base64EncodedString()
    }

    static func parseDate(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: text)
    }

    private static func ymdString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func shareColor(from exhibition: Exhibition) -> ExhibitionSharePayload.RGB? {
        guard let r = exhibition.colorR, let g = exhibition.colorG, let b = exhibition.colorB else { return nil }
        return ExhibitionSharePayload.RGB(r: Int(r), g: Int(g), b: Int(b))
    }

    private static func posterThumbBase64(from exhibition: Exhibition) -> String? {
        guard let data = exhibition.posterThumbData, !data.isEmpty else { return nil }
        let maxBytes = 30_000
        if data.count <= maxBytes {
            return data.base64EncodedString()
        }
        guard let image = UIImage(data: data) else { return nil }
        if let compressed = compress(image: image, maxBytes: maxBytes) {
            return compressed.base64EncodedString()
        }
        return nil
    }

    private static func compress(image: UIImage, maxBytes: Int) -> Data? {
        let maxSide: CGFloat = 120
        let scale = max(image.size.width, image.size.height) / maxSide
        let target = (scale > 1) ? CGSize(width: image.size.width / scale, height: image.size.height / scale) : image.size
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        for quality in stride(from: 0.6, through: 0.2, by: -0.1) {
            if let data = resized.jpegData(compressionQuality: quality),
               data.count <= maxBytes {
                return data
            }
        }
        return resized.jpegData(compressionQuality: 0.2)
    }

    private static func shareSchedule(from exhibition: Exhibition) -> ExhibitionSharePayload.Schedule? {
        let hasAny = exhibition.scheduleOpenTime != nil ||
            exhibition.scheduleCloseTime != nil ||
            exhibition.scheduleLastEntryTime != nil ||
            !exhibition.scheduleClosedWeekdays.isEmpty ||
            exhibition.scheduleHolidayHandling != nil ||
            !exhibition.scheduleClosedDateRules.isEmpty ||
            !exhibition.scheduleOpenDateRules.isEmpty ||
            !exhibition.scheduleSpecialOpenings.isEmpty
        guard hasAny else { return nil }
        return ExhibitionSharePayload.Schedule(
            openTime: exhibition.scheduleOpenTime,
            closeTime: exhibition.scheduleCloseTime,
            lastEntryTime: exhibition.scheduleLastEntryTime,
            closedWeekdays: exhibition.scheduleClosedWeekdays,
            holidayHandling: exhibition.scheduleHolidayHandling,
            closedDateRules: exhibition.scheduleClosedDateRules,
            openDateRules: exhibition.scheduleOpenDateRules,
            specialOpenings: exhibition.scheduleSpecialOpenings
        )
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var s = string.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (s.count % 4)
        if padding < 4 {
            s.append(String(repeating: "=", count: padding))
        }
        return Data(base64Encoded: s)
    }

    private static func isNetworkAvailable() async -> Bool {
        #if canImport(Network)
        let monitor = NWPathMonitor()
        return await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.resume(returning: path.status == .satisfied)
                monitor.cancel()
            }
            let queue = DispatchQueue(label: "ExhibitionShareService.Network")
            monitor.start(queue: queue)
        }
        #else
        return true
        #endif
    }
}

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseStorage)
extension ExhibitionShareService {
    private static func makeRemoteShareURL(for exhibition: Exhibition) async -> URL? {
        do {
            try await ensureSignedIn()
            let shareId = UUID().uuidString
            let posterURL = try await uploadPosterThumb(from: exhibition, shareId: shareId)
            let payload = ExhibitionSharePayload(
                id: exhibition.id,
                title: exhibition.title,
                venue: exhibition.venue,
                startDate: Self.ymdString(exhibition.startDate),
                endDate: Self.ymdString(exhibition.endDate),
                address: exhibition.address,
                url: exhibition.url?.absoluteString,
                latitude: exhibition.latitude,
                longitude: exhibition.longitude,
                color: shareColor(from: exhibition),
                posterThumbBase64: nil,
                posterThumbURL: posterURL?.absoluteString,
                admissionFees: exhibition.admissionFeeRules,
                reservationRequired: exhibition.reservationRequired,
                schedule: shareSchedule(from: exhibition)
            )
            let data = try JSONEncoder().encode(payload)
            guard let json = String(data: data, encoding: .utf8) else { return nil }
            let doc = Firestore.firestore().collection("sharedExhibitions").document(shareId)
            try await setDocument(doc, data: [
                "payload": json,
                "createdAt": FieldValue.serverTimestamp()
            ])
            var comps = URLComponents()
            comps.scheme = "https"
            comps.host = host
            comps.path = path
            comps.queryItems = [URLQueryItem(name: "id", value: shareId)]
            return comps.url
        } catch {
            return nil
        }
    }

    private static func fetchRemotePayload(id: String) async -> ExhibitionSharePayload? {
        do {
            try await ensureSignedIn()
            let doc = Firestore.firestore()
                .collection("sharedExhibitions")
                .document(id)
            let snapshot = try await getDocument(doc)
            guard let json = snapshot.data()?["payload"] as? String,
                  let data = json.data(using: .utf8)
            else { return nil }
            return try JSONDecoder().decode(ExhibitionSharePayload.self, from: data)
        } catch {
            return nil
        }
    }

    private static func uploadPosterThumb(from exhibition: Exhibition, shareId: String) async throws -> URL? {
        guard let data = exhibition.posterThumbData, !data.isEmpty else { return nil }
        let maxBytes = 30_000
        let uploadData: Data
        if data.count <= maxBytes {
            uploadData = data
        } else if let image = UIImage(data: data), let compressed = compress(image: image, maxBytes: maxBytes) {
            uploadData = compressed
        } else {
            uploadData = data
        }
        let ref = Storage.storage().reference()
            .child("sharedExhibitions")
            .child(shareId)
            .child("poster.jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await putData(ref, data: uploadData, metadata: meta)
        return try await downloadURL(ref)
    }

    private static func ensureSignedIn() async throws {
        if Auth.auth().currentUser != nil { return }
        _ = try await signInAnonymously()
    }

    private static func setDocument(_ doc: DocumentReference, data: [String: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            doc.setData(data) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func getDocument(_ doc: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot, Error>) in
            doc.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: NSError(domain: "ExhibitionShareService", code: -1))
                }
            }
        }
    }

    private static func signInAnonymously() async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().signInAnonymously { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: NSError(domain: "ExhibitionShareService", code: -1))
                }
            }
        }
    }

    private static func putData(_ ref: StorageReference, data: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
            ref.putData(data, metadata: metadata) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: NSError(domain: "ExhibitionShareService", code: -1))
                }
            }
        }
    }

    private static func downloadURL(_ ref: StorageReference) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            ref.downloadURL { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "ExhibitionShareService", code: -1))
                }
            }
        }
    }
}
#else
extension ExhibitionShareService {
    private static func makeRemoteShareURL(for exhibition: Exhibition) async -> URL? {
        return nil
    }

    private static func fetchRemotePayload(id: String) async -> ExhibitionSharePayload? {
        return nil
    }
}
#endif
