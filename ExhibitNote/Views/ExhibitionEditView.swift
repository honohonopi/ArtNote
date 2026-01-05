//
//  ExhibitionEditView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/28.
//

import SwiftUI
import CoreData
import CoreLocation
import MapKit
import PhotosUI
import UIKit

struct ExhibitionEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var venue: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var color: Color
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var localPreviewImage: UIImage? = nil   // 直近で選んだ画像のプレビュー
    @State private var showLibrary = false
    
    @State private var addressLine: String = ""
    @State private var tempCoordinate: CLLocationCoordinate2D? = nil
    @State private var mapPickerPayload: MapPayload? = nil
    @State private var previewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    
    @State private var scheduleOpenTime: String? = nil
    @State private var scheduleCloseTime: String? = nil
    @State private var scheduleLastEntryTime: String? = nil
    @State private var scheduleClosedWeekdays: [Weekday] = []
    @State private var scheduleHolidayHandling: HolidayHandling? = nil
    @State private var scheduleClosedDates: [Date] = []
    @State private var scheduleOpenDates: [Date] = []
    @State private var scheduleSpecialOpenings: [SpecialOpening] = []
    @State private var isScheduleExpanded = false
    private struct MapPayload: Identifiable { let id = UUID(); let query: String }
    private struct IdentCoord: Identifiable { let id = UUID(); let coord: CLLocationCoordinate2D }
    
    let exhibition: Exhibition
    
    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        _title = State(initialValue: exhibition.title)
        _venue = State(initialValue: exhibition.venue)
        _addressLine = State(initialValue: exhibition.address ?? "")
        _startDate = State(initialValue: exhibition.startDate)
        _endDate = State(initialValue: exhibition.endDate)
        if let ui = exhibition.uiColor { _color = State(initialValue: Color(ui)) }
        else { _color = State(initialValue: .blue) }
        if let c = exhibition.coordinate {
            _tempCoordinate = State(initialValue: c)
            _previewRegion = State(initialValue:
                                    MKCoordinateRegion(center: c, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01))
            )
        }
        _scheduleOpenTime = State(initialValue: exhibition.scheduleOpenTime)
        _scheduleCloseTime = State(initialValue: exhibition.scheduleCloseTime)
        _scheduleLastEntryTime = State(initialValue: exhibition.scheduleLastEntryTime)
        _scheduleClosedWeekdays = State(initialValue:
            exhibition.scheduleClosedWeekdays.compactMap { Weekday(rawValue: $0.lowercased()) }
        )
        _scheduleHolidayHandling = State(initialValue: parseHolidayHandling(exhibition.scheduleHolidayHandling))
        _scheduleClosedDates = State(initialValue: exhibition.scheduleClosedDates)
        _scheduleOpenDates = State(initialValue: exhibition.scheduleOpenDates)
        _scheduleSpecialOpenings = State(initialValue: exhibition.scheduleSpecialOpenings.compactMap { record in
            if record.ruleType == "weekday",
               let raw = record.weekday?.lowercased(),
               let weekday = Weekday(rawValue: raw) {
                return SpecialOpening(rule: .weekday(weekday),
                                      openTime: record.openTime,
                                      closeTime: record.closeTime,
                                      lastEntryTime: record.lastEntryTime,
                                      note: record.note)
            }
            if let date = record.date {
                return SpecialOpening(rule: .date(date),
                                      openTime: record.openTime,
                                      closeTime: record.closeTime,
                                      lastEntryTime: record.lastEntryTime,
                                      note: record.note)
            }
            return nil
        })
        _isScheduleExpanded = State(initialValue: !exhibition.scheduleClosedWeekdays.isEmpty
                                     || exhibition.scheduleOpenTime != nil
                                     || exhibition.scheduleCloseTime != nil
                                     || exhibition.scheduleLastEntryTime != nil
                                     || !exhibition.scheduleClosedDates.isEmpty
                                     || !exhibition.scheduleOpenDates.isEmpty
                                     || !exhibition.scheduleSpecialOpenings.isEmpty
                                     || exhibition.scheduleHolidayHandling != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("展覧会名", text: $title)
                    TextField("会場", text: $venue)
                    HStack(spacing: 8) {
                        TextField("会場住所（任意）", text: $addressLine)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        Button {
                            // 住所 > 会場 > どちらも空なら何もしない
                            let q = addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? venue.trimmingCharacters(in: .whitespacesAndNewlines)
                            : addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !q.isEmpty else { return }
                            mapPickerPayload = .init(query: q)
                        } label: {
                            Image(systemName: "mappin.and.ellipse")
                                .imageScale(.large)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("地図で位置を選ぶ")
                    }
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                    DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                }
                Section {
                    DisclosureGroup("開館情報", isExpanded: $isScheduleExpanded) {
                        scheduleEditor
                    }
                }
                Section("帯の色") {
                    ColorPicker("色", selection: $color, supportsOpacity: false)
                }
                // 追加：ポスター差し替え
                Section("ポスター") {
                    HStack(spacing: 12) {
                        // プレビュー（サムネ or 直近選択画像 or プレースホルダ）
                        PosterPreviewView(
                            data: exhibition.posterThumbData,
                            fallbackColor: (exhibition.swiftUIColor ?? .gray)
                        )
                        .overlay(
                            Group {
                                if let img = localPreviewImage {
                                    // 直近に選択した画像を一時的に被せて見せる
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                        )
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Menu {
                            Button {
                                showLibrary = true   // ← PhotosPicker を表示
                            } label: {
                                Label("写真ライブラリから選ぶ", systemImage: "photo.on.rectangle")
                            }
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showCamera = true
                                } label: {
                                    Label("カメラで撮る", systemImage: "camera.viewfinder")
                                }
                            }
                            if exhibition.posterThumbData != nil {
                                Button(role: .destructive) {
                                    exhibition.posterThumbData = nil
                                    localPreviewImage = nil
                                } label: {
                                    Label("ポスターを削除", systemImage: "trash")
                                }
                            }
                        } label: {
                            Label("ポスター画像を変更", systemImage: "text.viewfinder")
                        }
                    }
                }
            }
            .navigationTitle("編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 日付の整合性
                        if endDate < startDate { endDate = startDate }
                        // モデルへ反映
                        exhibition.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        exhibition.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
                        exhibition.address = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        exhibition.startDate = startDate
                        exhibition.endDate = endDate
                        exhibition.setColor(UIColor(color))
                        exhibition.scheduleOpenTime = scheduleOpenTime
                        exhibition.scheduleCloseTime = scheduleCloseTime
                        exhibition.scheduleLastEntryTime = scheduleLastEntryTime
                        exhibition.scheduleClosedWeekdays = scheduleClosedWeekdays.map { $0.rawValue }
                        exhibition.scheduleHolidayHandling = scheduleHolidayHandling.map { holidayHandlingRaw($0) }
                        exhibition.scheduleClosedDates = scheduleClosedDates
                        exhibition.scheduleOpenDates = scheduleOpenDates
                        exhibition.scheduleSpecialOpenings = scheduleSpecialOpenings.map {
                            Exhibition.SpecialOpeningRecord(
                                ruleType: specialOpeningRuleType($0.rule),
                                date: specialOpeningRuleDate($0.rule),
                                weekday: specialOpeningRuleWeekday($0.rule),
                                openTime: $0.openTime,
                                closeTime: $0.closeTime,
                                lastEntryTime: $0.lastEntryTime,
                                note: $0.note
                            )
                        }
                        if let c = tempCoordinate {
                            exhibition.setCoordinate(c)
                        } else {
                        }
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .sheet(item: $mapPickerPayload) { payload in
                NavigationStack {
                    MapPickerView(seed: tempCoordinate, initialQuery: payload.query) { pickedCoord, pickedAddress in
                        // 反映
                        tempCoordinate = pickedCoord
                        previewRegion.center = pickedCoord
                        previewRegion.span = .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        if let addr = pickedAddress, !addr.isEmpty {
                            // 住所が未入力なら埋める（常に上書きしたい場合は else 側を上書きに）
                            if addressLine.isEmpty { addressLine = addr }
                        }
                    }
                }
            }
            // MARK: - ライブラリ（PhotosPicker）
            .sheet(isPresented: $showLibrary) {
                PhotoLibraryPicker { image in
                    if let img = image { handlePickedImage(img) }
                    showLibrary = false
                }
            }
            // MARK: - カメラ
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    if let img = image { handlePickedImage(img) }
                    showCamera = false
                }
            }
        }
    }

    private var scheduleEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("開館時間") {
                DatePicker("開館", selection: timeBinding($scheduleOpenTime, defaultTime: "10:00"), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Text("〜")
                DatePicker("閉館", selection: timeBinding($scheduleCloseTime, defaultTime: "18:00"), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .environment(\.calendar, Calendar(identifier: .gregorian))

            HStack {
                Text("最終入場")
                Spacer()
                if scheduleLastEntryTime != nil {
                    DatePicker("最終入場", selection: timeBinding($scheduleLastEntryTime, defaultTime: "17:30"), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Button("削除") { scheduleLastEntryTime = nil }
                        .font(.caption)
                        .buttonStyle(.bordered)
                } else {
                    Button("追加") { scheduleLastEntryTime = scheduleCloseTime }
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
            }
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .environment(\.calendar, Calendar(identifier: .gregorian))

            VStack(alignment: .leading, spacing: 6) {
                Text("休館曜日").font(.subheadline)
                HStack(spacing: 6) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        let selected = scheduleClosedWeekdays.contains(day)
                        Button(weekdayShortLabel(day)) {
                            toggleWeekday(day)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selected ? Color.blue.opacity(0.2) : Color(.systemGray6))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
            }

            Picker("祝日対応", selection: holidayHandlingBinding()) {
                Text("規定なし").tag("NONE")
                Text("祝日は開館").tag("OPEN_ON_HOLIDAY")
                Text("祝日開館・翌平日休館").tag("OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY")
            }

            dateListEditor(title: "特別休館日", dates: $scheduleClosedDates)
            dateListEditor(title: "特別開館日", dates: $scheduleOpenDates)

            specialOpeningsEditor
        }
    }

    private func timeBinding(_ value: Binding<String?>, defaultTime: String) -> Binding<Date> {
        Binding<Date>(
            get: {
                timeDate(from: value.wrappedValue) ?? timeDate(from: defaultTime) ?? Date()
            },
            set: { newDate in
                value.wrappedValue = timeString(from: newDate)
            }
        )
    }

    private func timeDate(from text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: text)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func weekdayShortLabel(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        case .sunday: return "日"
        }
    }

    private func weekdayLabel(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: return "毎週月曜"
        case .tuesday: return "毎週火曜"
        case .wednesday: return "毎週水曜"
        case .thursday: return "毎週木曜"
        case .friday: return "毎週金曜"
        case .saturday: return "毎週土曜"
        case .sunday: return "毎週日曜"
        }
    }

    private func toggleWeekday(_ weekday: Weekday) {
        if let idx = scheduleClosedWeekdays.firstIndex(of: weekday) {
            scheduleClosedWeekdays.remove(at: idx)
        } else {
            scheduleClosedWeekdays.append(weekday)
            scheduleClosedWeekdays.sort { $0.calendarValue < $1.calendarValue }
        }
    }

    private func holidayHandlingBinding() -> Binding<String> {
        Binding<String>(
            get: { scheduleHolidayHandling.map { holidayHandlingRaw($0) } ?? "NONE" },
            set: { raw in
                switch raw {
                case "OPEN_ON_HOLIDAY":
                    scheduleHolidayHandling = .openOnHoliday
                case "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY":
                    scheduleHolidayHandling = .openOnHolidayCloseNextWeekday
                default:
                    scheduleHolidayHandling = .none
                }
            }
        )
    }

    private func holidayHandlingRaw(_ value: HolidayHandling) -> String {
        switch value {
        case .none:
            return "NONE"
        case .openOnHoliday:
            return "OPEN_ON_HOLIDAY"
        case .openOnHolidayCloseNextWeekday:
            return "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY"
        }
    }

    private func dateListEditor(title: String, dates: Binding<[Date]>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Button {
                    dates.wrappedValue.append(Date())
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }
            ForEach(dates.wrappedValue.indices, id: \.self) { idx in
                HStack {
                    DatePicker("", selection: Binding(
                        get: { dates.wrappedValue[idx] },
                        set: { dates.wrappedValue[idx] = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    Button(role: .destructive) {
                        dates.wrappedValue.remove(at: idx)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var specialOpeningsEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("特別開館").font(.subheadline)
                Spacer()
                Button {
                    let open = scheduleOpenTime ?? "10:00"
                    let close = scheduleCloseTime ?? "18:00"
                    scheduleSpecialOpenings.append(
                        SpecialOpening(rule: .date(Date()),
                                       openTime: open,
                                       closeTime: close,
                                       lastEntryTime: scheduleLastEntryTime,
                                       note: nil)
                    )
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }
            ForEach(scheduleSpecialOpenings.indices, id: \.self) { idx in
                VStack(alignment: .leading, spacing: 6) {
                    switch scheduleSpecialOpenings[idx].rule {
                    case .date(let date):
                        DatePicker("日付", selection: Binding(
                            get: { date },
                            set: { newDate in
                                scheduleSpecialOpenings[idx].rule = .date(newDate)
                            }
                        ), displayedComponents: .date)
                        .labelsHidden()
                    case .weekday(let weekday):
                        Text(weekdayLabel(weekday))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        DatePicker("開館", selection: timeBinding(
                            Binding<String?>(
                                get: { scheduleSpecialOpenings[idx].openTime },
                                set: { scheduleSpecialOpenings[idx].openTime = $0 ?? "" }
                            ),
                            defaultTime: "10:00"
                        ), displayedComponents: .hourAndMinute).labelsHidden()
                        Text("〜")
                        DatePicker("閉館", selection: timeBinding(
                            Binding<String?>(
                                get: { scheduleSpecialOpenings[idx].closeTime },
                                set: { scheduleSpecialOpenings[idx].closeTime = $0 ?? "" }
                            ),
                            defaultTime: "18:00"
                        ), displayedComponents: .hourAndMinute).labelsHidden()
                    }
                    HStack {
                        Text("最終入場")
                        Spacer()
                        if scheduleSpecialOpenings[idx].lastEntryTime != nil {
                            DatePicker("最終入場", selection: timeBinding(
                                Binding<String?>(
                                    get: { scheduleSpecialOpenings[idx].lastEntryTime },
                                    set: { scheduleSpecialOpenings[idx].lastEntryTime = $0 }
                                ),
                                defaultTime: "17:30"
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            Button("削除") { scheduleSpecialOpenings[idx].lastEntryTime = nil }
                                .font(.caption)
                                .buttonStyle(.bordered)
                        } else {
                            Button("追加") { scheduleSpecialOpenings[idx].lastEntryTime = scheduleSpecialOpenings[idx].closeTime }
                                .font(.caption)
                                .buttonStyle(.bordered)
                        }
                    }
                    HStack {
                        Text("メモ")
                        TextField("任意", text: Binding(
                            get: { scheduleSpecialOpenings[idx].note ?? "" },
                            set: { scheduleSpecialOpenings[idx].note = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    Button(role: .destructive) {
                        scheduleSpecialOpenings.remove(at: idx)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 6)
            }
        }
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .environment(\.calendar, Calendar(identifier: .gregorian))
    }

    private func parseHolidayHandling(_ value: String?) -> HolidayHandling? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !raw.isEmpty
        else { return nil }
        switch raw {
        case "NONE": return .none
        case "OPEN_ON_HOLIDAY": return .openOnHoliday
        case "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY": return .openOnHolidayCloseNextWeekday
        default: return nil
        }
    }

    private func specialOpeningRuleType(_ rule: SpecialOpening.Rule) -> String {
        switch rule {
        case .date: return "date"
        case .weekday: return "weekday"
        }
    }

    private func specialOpeningRuleDate(_ rule: SpecialOpening.Rule) -> Date? {
        switch rule {
        case .date(let date): return date
        case .weekday: return nil
        }
    }

    private func specialOpeningRuleWeekday(_ rule: SpecialOpening.Rule) -> String? {
        switch rule {
        case .date: return nil
        case .weekday(let weekday): return weekday.rawValue
        }
    }
    // MARK: - 画像を受け取ってモデルへ反映
    private func handlePickedImage(_ image: UIImage) {
        // サムネ生成（軽量化して保存）
        if let thumb = ImageThumbService.makeThumbnail(image) {
            exhibition.posterThumbData = thumb
        }
        // 編集画面内の即時プレビュー
        localPreviewImage = image

        // （任意）支配色をテーマに反映したい場合：
         if let ui = DominantColorService.dominantColor(from: image) {
             color = Color(ui)
             exhibition.setColor(ui)
         }
    }

    // MARK: - プレビュー（サムネ or フォールバック）
    private struct PosterPreviewView: View {
        let data: Data?
        let fallbackColor: Color
        var body: some View {
            if let d = data, let ui = UIImage(data: d) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    fallbackColor.opacity(0.15)
                    Image(systemName: "photo.on.rectangle")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - CameraPicker（UIKit ラッパー）
    private struct CameraPicker: UIViewControllerRepresentable {
        var onComplete: (UIImage?) -> Void
        func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }
        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.allowsEditing = false
            picker.delegate = context.coordinator
            return picker
        }
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
        final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
            let onComplete: (UIImage?) -> Void
            init(onComplete: @escaping (UIImage?) -> Void) { self.onComplete = onComplete }
            func imagePickerController(_ picker: UIImagePickerController,
                                       didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                let img = (info[.originalImage] as? UIImage)
                picker.dismiss(animated: true) { self.onComplete(img) }
            }
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                picker.dismiss(animated: true) { self.onComplete(nil) }
            }
        }
    }
    // MARK: - PhotoLibraryPicker (PHPicker ラッパー)
    private struct PhotoLibraryPicker: UIViewControllerRepresentable {
        var onComplete: (UIImage?) -> Void

        func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

        func makeUIViewController(context: Context) -> PHPickerViewController {
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.selectionLimit = 1
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

        final class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let onComplete: (UIImage?) -> Void
            init(onComplete: @escaping (UIImage?) -> Void) { self.onComplete = onComplete }

            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                guard let first = results.first else {
                    picker.dismiss(animated: true) { self.onComplete(nil) }
                    return
                }
                let provider = first.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        DispatchQueue.main.async {
                            picker.dismiss(animated: true) {
                                self.onComplete(image as? UIImage)
                            }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                        let img = data.flatMap { UIImage(data: $0) }
                        DispatchQueue.main.async {
                            picker.dismiss(animated: true) {
                                self.onComplete(img)
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        picker.dismiss(animated: true) { self.onComplete(nil) }
                    }
                }
            }
        }
    }


}
