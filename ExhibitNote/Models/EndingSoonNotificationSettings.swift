import Foundation

struct EndingSoonNotificationSettings: Equatable {
    var isEnabled: Bool = true
    var hour: Int = 9
    var minute: Int = 0

    var notificationTime: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    /// DatePickerとの受け渡し用。設定として保持するのは時と分だけ。
    var pickerDate: Date {
        get { Calendar.japan.date(from: notificationTime) ?? Date() }
        set {
            let components = Calendar.japan.dateComponents([.hour, .minute], from: newValue)
            guard let hour = components.hour, let minute = components.minute else { return }
            self.hour = hour
            self.minute = minute
        }
    }
}
