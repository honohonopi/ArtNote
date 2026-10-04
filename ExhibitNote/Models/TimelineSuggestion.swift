import Foundation

struct TimelineSuggestion: Identifiable {
    let exhibition: Exhibition
    let availableStart: Date
    let availableEnd: Date

    var id: String {
        let start = Int(availableStart.timeIntervalSince1970)
        let end = Int(availableEnd.timeIntervalSince1970)
        return "\(exhibition.persistentModelID)-\(start)-\(end)"
    }
}
