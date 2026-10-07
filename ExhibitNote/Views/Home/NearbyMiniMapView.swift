import CoreLocation
import MapKit
import SwiftUI

struct NearbyMapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let isHere: Bool
}

struct NearbyMiniMapView: View {
    @Binding var region: MKCoordinateRegion
    let pins: [NearbyMapPin]
    @Binding var selectedPinID: String?

    var body: some View {
        Map(
            coordinateRegion: $region,
            interactionModes: [.zoom, .pan],
            showsUserLocation: false,
            annotationItems: pins
        ) { pin in
            MapAnnotation(coordinate: pin.coordinate) {
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
                .accessibilityLabel(pin.title)
                .contentShape(Rectangle())
            }
        }
    }
}
