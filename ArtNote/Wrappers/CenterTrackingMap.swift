//
//  CenterTrackingMap.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/27.
//

import SwiftUI
import MapKit

struct CenterTrackingMap: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var center: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.setRegion(region, animated: false)
        map.showsCompass = false
        map.showsScale = false
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // region が外から変わったときだけ反映（無限ループ回避）
        if !equal(uiView.region, region) {
            uiView.setRegion(region, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private let parent: CenterTrackingMap
        init(_ parent: CenterTrackingMap) { self.parent = parent }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let r = mapView.region
            if !equal(parent.region, r) {
                parent.region = r
            }
            let c = mapView.centerCoordinate
            if parent.center.latitude != c.latitude || parent.center.longitude != c.longitude {
                parent.center = c
            }
            NotificationCenter.default.post(name: .MKMapViewRegionDidChange, object: nil)
        }
    }
}

// 近似比較（MKMapView の内部更新で微妙にズレるのを吸収）
private func equal(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
    let eps = 1e-6
    return abs(a.center.latitude - b.center.latitude) < eps &&
           abs(a.center.longitude - b.center.longitude) < eps &&
           abs(a.span.latitudeDelta - b.span.latitudeDelta) < eps &&
           abs(a.span.longitudeDelta - b.span.longitudeDelta) < eps
}
