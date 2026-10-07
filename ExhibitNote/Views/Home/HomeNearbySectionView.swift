import SwiftUI
import CoreLocation
import MapKit

struct HomeNearbySectionView: View {
    @Binding var nearbyRadiusKm: Double

    let location: CLLocation?
    let authorization: CLAuthorizationStatus
    let items: [(Exhibition, Double)]
    let requestLocation: () -> Void
    let onSelectExhibition: (String) -> Void

    @State private var selectedPinID: String?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    private let displayLimit = 5

    private var pins: [NearbyMapPin] {
        var pins: [NearbyMapPin] = []
        if let coordinate = location?.coordinate {
            pins.append(NearbyMapPin(id: "here", coordinate: coordinate, title: "現在地", isHere: true))
        }
        for (exhibition, _) in items.prefix(displayLimit) {
            if let coordinate = exhibition.coordinate {
                pins.append(NearbyMapPin(
                    id: exhibition.id,
                    coordinate: coordinate,
                    title: exhibition.title,
                    isHere: false
                ))
            }
        }
        return pins
    }

    private var spanForRadius: MKCoordinateSpan {
        let degrees = max(nearbyRadiusKm / 111.0, 0.02)
        return MKCoordinateSpan(latitudeDelta: degrees, longitudeDelta: degrees)
    }

    var body: some View {
        Section {
            if (authorization == .authorizedAlways || authorization == .authorizedWhenInUse),
               !pins.isEmpty {
                NearbyMiniMapView(region: $mapRegion, pins: pins, selectedPinID: $selectedPinID)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            switch authorization {
            case .authorizedAlways, .authorizedWhenInUse:
                if items.isEmpty {
                    ContentUnavailableView("近くで開催中の展示はありません", systemImage: "mappin.and.ellipse")
                } else {
                    ForEach(Array(items.prefix(displayLimit)), id: \.0.id) { ex, km in
                        NavigationLink {
                            ExhibitionDetailView(exhibition: ex)
                        } label: {
                            ExhibitionRowView(ex: ex, distanceKm: km)
                                .padding(.vertical, 4)
                        }
                        .overlay(alignment: .leading) {
                            if selectedPinID == ex.id {
                                Rectangle()
                                    .fill(Color.red.opacity(0.5))
                                    .frame(width: 4)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.25), value: selectedPinID)
                        .id("nearby-\(ex.id)")
                    }
                }
            case .notDetermined:
                Button(action: requestLocation) {
                    Label("近くの展示を表示するには位置情報を許可", systemImage: "location")
                }
            default:
                ContentUnavailableView("位置情報の許可が必要です", systemImage: "location.slash")
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("近くで開催中")
                Spacer()
                Text("\(Int(nearbyRadiusKm))km")
                Menu {
                    Picker("範囲の選択", selection: $nearbyRadiusKm) {
                        Text("3km").tag(3.0)
                        Text("5km").tag(5.0)
                        Text("10km").tag(10.0)
                        Text("20km").tag(20.0)
                        Text("50km").tag(50.0)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .imageScale(.medium)
                        .padding(.leading, 6)
                }
            }
        }
        .onChange(of: location, initial: true) {
            if let coordinate = location?.coordinate {
                mapRegion.center = coordinate
                mapRegion.span = spanForRadius
            }
        }
        .onChange(of: nearbyRadiusKm) {
            mapRegion.span = spanForRadius
        }
        .onChange(of: selectedPinID) {
            guard let selectedPinID, selectedPinID != "here" else { return }
            onSelectExhibition(selectedPinID)
        }
    }
}
