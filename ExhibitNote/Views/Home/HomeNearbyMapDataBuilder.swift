import CoreLocation
import MapKit

struct HomeNearbyMapDataBuilder {
    struct MapData {
        let pins: [NearbyMapPin]
        let span: MKCoordinateSpan
    }

    static let displayLimit = 5
    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    func build(
        location: CLLocation?,
        items: [(Exhibition, Double)],
        radiusKm: Double
    ) -> MapData {
        MapData(
            pins: makePins(location: location, items: items),
            span: makeSpan(radiusKm: radiusKm)
        )
    }

    private func makePins(
        location: CLLocation?,
        items: [(Exhibition, Double)]
    ) -> [NearbyMapPin] {
        var pins: [NearbyMapPin] = []
        if let coordinate = location?.coordinate {
            pins.append(NearbyMapPin(
                id: "here",
                coordinate: coordinate,
                title: "現在地",
                isHere: true
            ))
        }
        pins += items.prefix(Self.displayLimit).compactMap { exhibition, _ in
            guard let coordinate = exhibition.coordinate else { return nil }
            return NearbyMapPin(
                id: exhibition.id,
                coordinate: coordinate,
                title: exhibition.title,
                isHere: false
            )
        }
        return pins
    }

    private func makeSpan(radiusKm: Double) -> MKCoordinateSpan {
        let degrees = max(radiusKm / 111.0, 0.02)
        return MKCoordinateSpan(latitudeDelta: degrees, longitudeDelta: degrees)
    }
}
