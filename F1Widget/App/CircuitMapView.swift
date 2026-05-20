//
//  CircuitMapView.swift
//  F1Widget
//
//  Renders a satellite view of the circuit's actual location on Earth, using
//  MapKit. The map is centered + zoomed using the same GeoJSON bbox that
//  CircuitDiagramCache already loads for the track outline.
//

import SwiftUI
import MapKit

struct CircuitMapView: View {
    let circuitId: String

    @State private var position: MapCameraPosition = .automatic
    private var cache: CircuitDiagramCache { .shared }

    var body: some View {
        Map(position: $position, interactionModes: [])
            .mapStyle(.imagery(elevation: .realistic))
            .task {
                await cache.load(circuitId: circuitId)
                updateRegion()
            }
            .onChange(of: cache.coords[circuitId] ?? []) { _, _ in
                updateRegion()
            }
    }

    private func updateRegion() {
        guard let coords = cache.coords[circuitId], !coords.isEmpty else { return }
        let lons = coords.map(\.x)
        let lats = coords.map(\.y)
        guard let minLon = lons.min(), let maxLon = lons.max(),
              let minLat = lats.min(), let maxLat = lats.max() else { return }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.8, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.8, 0.01)
        )
        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}
