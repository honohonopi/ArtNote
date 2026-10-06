//
//  ExhibitionDetailViewModel.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import SwiftUI
import Observation
import MapKit
import UIKit

@MainActor
@Observable
final class ExhibitionDetailViewModel {
    let exhibition: Exhibition

    var showDeleteConfirm = false
    var showEdit = false
    var showPlanner = false
    var visitDate = Date()
    var showAddDone = false
    var showMapChoice = false
    var showAdmissionDetails = false
    var showScheduleDetails = false

    init(exhibition: Exhibition) {
        self.exhibition = exhibition
    }

    var hasScheduleInfo: Bool {
        if exhibition.scheduleOpenTime != nil || exhibition.scheduleCloseTime != nil || exhibition.scheduleLastEntryTime != nil {
            return true
        }
        if !exhibition.scheduleClosedWeekdays.isEmpty {
            return true
        }
        if exhibition.scheduleHolidayHandling != nil {
            return true
        }
        if !closedDateRules.isEmpty || !openDateRules.isEmpty || !specialOpenings.isEmpty {
            return true
        }
        return false
    }

    var scheduleTimeText: String? {
        let open = exhibition.scheduleOpenTime?.trimmingCharacters(in: .whitespacesAndNewlines)
        let close = exhibition.scheduleCloseTime?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open, !open.isEmpty, let close, !close.isEmpty {
            return "\(open)〜\(close)"
        }
        if let open, !open.isEmpty {
            return "\(open)〜"
        }
        if let close, !close.isEmpty {
            return "〜\(close)"
        }
        return nil
    }

    var scheduleClosedWeekdaysText: String {
        let map: [String: String] = [
            "monday": "月",
            "tuesday": "火",
            "wednesday": "水",
            "thursday": "木",
            "friday": "金",
            "saturday": "土",
            "sunday": "日"
        ]
        let labels = exhibition.scheduleClosedWeekdays.compactMap { map[$0.lowercased()] }
        return labels.joined(separator: "・")
    }

    var closedDateRules: [DateRule] {
        exhibition.scheduleClosedDateRules.compactMap { $0.toDateRule() }
    }

    var openDateRules: [DateRule] {
        exhibition.scheduleOpenDateRules.compactMap { $0.toDateRule() }
    }

    var specialOpenings: [SpecialOpening] {
        exhibition.scheduleSpecialOpenings.compactMap { $0.toSpecialOpening() }
    }

    func holidayHandlingText(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        switch raw.uppercased() {
        case "NONE":
            return "祝日対応なし"
        case "OPEN_ON_HOLIDAY":
            return "祝日は開館"
        case "OPEN_ON_HOLIDAY_CLOSE_NEXT_WEEKDAY":
            return "祝日開館・翌平日休館"
        default:
            return nil
        }
    }

    func reservationStatusText(_ value: Bool?) -> String {
        switch value {
        case .some(true):
            return "事前予約制"
        case .some(false):
            return "予約不要"
        case .none:
            return "記載なし"
        }
    }

    func resolvedAdmissionFee(for userCategoryRaw: String) -> AdmissionFeeRule? {
        let userCategory = UserTicketCategory(rawValue: userCategoryRaw) ?? .adult
        return exhibition.resolvedAdmissionFee(for: userCategory)
    }

    var displayAdmissionFees: [AdmissionFeeRule] {
        exhibition.admissionFeeRules.filter { fee in
            fee.priceYen != nil ||
            (fee.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }
    }

    func dateRuleText(_ rule: DateRule) -> String {
        let base: String
        switch rule.rule {
        case .date(let date):
            base = date.ymdString
        case .range(let start, let end):
            base = "\(start.ymdString)〜\(end.ymdString)"
        }
        if let note = rule.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return "\(base) \(note)"
        }
        return base
    }

    func specialOpeningText(_ opening: SpecialOpening) -> String {
        let label: String
        switch opening.rule {
        case .date(let date):
            label = date.ymdString
        case .weekday(let weekday):
            label = weeklyLabel(weekday)
        case .range(let start, let end):
            label = "\(start.ymdString)〜\(end.ymdString)"
        }
        return "\(label) \(opening.openTime)〜\(opening.closeTime)"
    }

    func weeklyLabel(_ weekday: Weekday) -> String {
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

    func openInAppleMaps(address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        let url = URL(string: "http://maps.apple.com/?daddr=\(encoded)")!
        UIApplication.shared.open(url)
    }

    func openInGoogleMaps(address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        let scheme = "comgooglemaps://?daddr=\(encoded)&directionsmode=driving"
        if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            let web = "https://www.google.com/maps/dir/?api=1&destination=\(encoded)"
            UIApplication.shared.open(URL(string: web)!)
        }
    }

    func openInAppleMaps(_ coord: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    func openInGoogleMaps(_ coord: CLLocationCoordinate2D, name: String) {
        let urlStr = "comgooglemaps://?daddr=\(coord.latitude),\(coord.longitude)&directionsmode=driving"
        if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            let webURL = URL(string: "https://maps.google.com/?q=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            UIApplication.shared.open(webURL)
        }
    }
}
