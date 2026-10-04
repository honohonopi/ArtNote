import Foundation

extension Calendar {
    /// 日本の展覧会の日付・時刻を解釈するための共通Calendar。
    /// 端末の時間帯や暦の設定には依存しない。
    static var japan: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.firstWeekday = 1
        return calendar
    }
}

extension DateFormatter {
    /// 表示・読み取りのどちらも日本時間を使う。書式は呼び出し元で指定する。
    static func japanese() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = .japan
        formatter.timeZone = Calendar.japan.timeZone
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }
}
