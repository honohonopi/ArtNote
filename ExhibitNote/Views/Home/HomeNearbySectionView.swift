import SwiftUI
import CoreLocation
import MapKit

struct HomeNearbySectionView: View {
    @Binding var nearbyRadiusKm: Double
    @Binding var mapRegion: MKCoordinateRegion

    let authorization: CLAuthorizationStatus
    let items: [(Exhibition, Double)]
    let displayLimit: Int
    let pins: [MapPin]
    let requestLocation: () -> Void
    let onRadiusEditingChanged: (Bool) -> Void

    @Binding var selectedPinID: String?          // ← Map の選択状態を受け取る
    @Binding var highlightedExID: String?

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
                            if highlightedExID == ex.id {
                                Rectangle()
                                    .fill(Color.red.opacity(0.5))
                                    .frame(width: 4)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.25), value: highlightedExID)
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
                    Picker("範囲の選択", selection: Binding(
                        get: { Int(nearbyRadiusKm) },
                        set: { newVal in
                            nearbyRadiusKm = Double(newVal)
                            onRadiusEditingChanged(false)
                        }
                    )) {
                        Text("3km").tag(3)
                        Text("5km").tag(5)
                        Text("10km").tag(10)
                        Text("20km").tag(20)
                        Text("50km").tag(50)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .imageScale(.medium)
                        .padding(.leading, 6)
                }
            }
        }
    }
}

struct MapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let isHere: Bool
    let exhibition: Exhibition?
}

struct NearbyMiniMapView: View {
    @Binding var region: MKCoordinateRegion
    let pins: [MapPin]
    @Binding var selectedPinID: String?

    var body: some View {
                Map(
                    coordinateRegion: $region,
                    interactionModes: [.zoom, .pan],
                    showsUserLocation: false,
                    annotationItems: pins
                ) { (pin: MapPin) in
                    MapAnnotation(coordinate: pin.coordinate) {
                        // タップで選択状態を更新 → リスト側がハイライト＆スクロール
                        Button {
                            selectedPinID = pin.id
                        } label: {
                            Image(systemName: pin.isHere ? "mappin.circle.fill" : "mappin.circle")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(
                                    pin.isHere ? Color.accentColor : (selectedPinID == pin.id ? Color.red : Color.gray)
                                )
                                .padding(4)
                                .background(.thinMaterial, in: Circle().inset(by: -2))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
    }
}
