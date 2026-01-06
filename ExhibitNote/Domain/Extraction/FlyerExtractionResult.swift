//
//  FlyerExtractionResult.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

struct FlyerExtractionResult {
    let rawText: String
    let classifiedLines: [FlyerClassifiedText]
    let titleCandidates: [String]
    let venueCandidates: [String]
    let venuePOI: String?
    let schedule: ScheduleExtraction?
    let dateCandidates: [(Date, Date)]
    let urlCandidates: [String]
    let admissionFees: [AdmissionFeeRule]?
    let reservationRequired: Bool?
}

struct ScheduleExtraction {
    let openTime: String?
    let closeTime: String?
    let lastEntryTime: String?
    let closedWeekdays: [Weekday]
    let holidayHandling: HolidayHandling?
    let closedDateRules: [DateRule]
    let openDateRules: [DateRule]
    let specialOpenings: [SpecialOpening]
}
