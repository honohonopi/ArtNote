import Foundation

/// 共有された展覧会データを、アプリ内で保存できる形式へ変換する。
struct ExhibitionImportService {
    func makeExhibition(
        from payload: ExhibitionSharePayload,
        posterThumbData: Data?
    ) -> Exhibition {
        let startDate = ExhibitionShareService.parseDate(payload.startDate) ?? Date()
        let parsedEndDate = ExhibitionShareService.parseDate(payload.endDate) ?? startDate
        let exhibition = Exhibition(
            title: payload.title,
            venue: payload.venue,
            address: payload.address,
            startDate: startDate,
            endDate: max(startDate, parsedEndDate),
            url: payload.url.flatMap { $0.normalizedWebURL() }
        )

        if let latitude = payload.latitude, let longitude = payload.longitude {
            exhibition.latitude = latitude
            exhibition.longitude = longitude
        }
        if let color = payload.color {
            exhibition.colorR = Int16(color.r)
            exhibition.colorG = Int16(color.g)
            exhibition.colorB = Int16(color.b)
        }

        exhibition.posterThumbData = posterThumbData
        exhibition.admissionFeeRules = payload.admissionFees
        exhibition.reservationRequired = payload.reservationRequired

        if let schedule = payload.schedule {
            exhibition.scheduleOpenTime = schedule.openTime
            exhibition.scheduleCloseTime = schedule.closeTime
            exhibition.scheduleLastEntryTime = schedule.lastEntryTime
            exhibition.scheduleClosedWeekdays = schedule.closedWeekdays
            exhibition.scheduleHolidayHandling = schedule.holidayHandling
            exhibition.scheduleClosedDateRules = schedule.closedDateRules
            exhibition.scheduleOpenDateRules = schedule.openDateRules
            exhibition.scheduleSpecialOpenings = schedule.specialOpenings
        }
        return exhibition
    }

    func loadPosterThumbnail(from payload: ExhibitionSharePayload) async -> Data? {
        if let base64 = payload.posterThumbBase64,
           let data = Data(base64Encoded: base64) {
            return data
        }
        guard let urlString = payload.posterThumbURL,
              let url = URL(string: urlString)
        else { return nil }

        return try? await URLSession.shared.data(from: url).0
    }
}
