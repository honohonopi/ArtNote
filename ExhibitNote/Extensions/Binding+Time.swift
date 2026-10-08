import SwiftUI

extension Binding where Value == String? {
    /// `HH:mm`形式の文字列を時刻選択用の`Date`として扱う。
    func timePickerDate(defaultTime: String) -> Binding<Date> {
        Binding<Date>(
            get: {
                TimeTextConverter.date(from: wrappedValue) ??
                    TimeTextConverter.date(from: defaultTime) ??
                    Date()
            },
            set: { wrappedValue = TimeTextConverter.string(from: $0) }
        )
    }
}

extension Binding where Value == String {
    /// `HH:mm`形式の文字列を時刻選択用の`Date`として扱う。
    func timePickerDate(defaultTime: String) -> Binding<Date> {
        Binding<Date>(
            get: {
                TimeTextConverter.date(from: wrappedValue) ??
                    TimeTextConverter.date(from: defaultTime) ??
                    Date()
            },
            set: { wrappedValue = TimeTextConverter.string(from: $0) }
        )
    }
}

private enum TimeTextConverter {
    static func date(from text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return formatter.date(from: text)
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    private static var formatter: DateFormatter {
        let formatter = DateFormatter.japanese()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}
