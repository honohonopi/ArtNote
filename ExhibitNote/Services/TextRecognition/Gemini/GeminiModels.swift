//
//  GeminiModels.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2026/01/06.
//

import Foundation

// MARK: - Flyer (basic)
struct GeminiFlyerResponse: Decodable {
    let title: String?
    let venue: String?
    let venuePoi: String?
    let period: GeminiPeriod?
    let regularSchedule: GeminiRegularSchedule?
    let exceptions: GeminiExceptions?
    let admission: GeminiAdmission?
    let reservation: GeminiReservation?
    let url: String?
}

struct GeminiPeriod: Decodable {
    let startDate: String?
    let endDate: String?
    let periodText: String?
}

struct GeminiRegularSchedule: Decodable {
    let openTime: String?
    let closeTime: String?
    let lastEntryTime: String?
    let closedWeekdays: [String]?
    let holidayHandling: String?
}

struct GeminiExceptions: Decodable {
    let closedDates: [String]?
    let openDates: [String]?
    let specialOpenings: [GeminiSpecialOpening]?
}

struct GeminiSpecialOpening: Decodable {
    let ruleType: String?
    let date: String?
    let startDate: String?
    let endDate: String?
    let openTime: String?
    let closeTime: String?
    let lastEntryTime: String?
    let note: String?
}

// MARK: - Extra info (admission / reservation)
struct GeminiExtraInfoResponse: Decodable {
    let admission: GeminiAdmission?
    let reservation: GeminiReservation?
}

struct GeminiAdmission: Decodable {
    let isFree: Bool?
    let fees: [GeminiAdmissionFee]?
}

struct GeminiAdmissionFee: Decodable {
    let category: String?
    let label: String?
    let priceYen: Int?
    let note: String?
}

struct GeminiReservation: Decodable {
    let required: Bool?
    let note: String?
}
