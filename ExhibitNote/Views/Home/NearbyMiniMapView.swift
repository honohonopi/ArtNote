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

    private var cameraPosition: Binding<MapCameraPosition> {
        Binding(
            get: { .region(region) },
            set: { position in
                if let updatedRegion = position.region {
                    region = updatedRegion
                }
            }
        )
    }

    var body: some View {
        Map(
            position: cameraPosition,
            interactionModes: [.zoom, .pan]
        ) {
            ForEach(pins) { pin in
                Annotation(pin.title, coordinate: pin.coordinate) {
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
}
