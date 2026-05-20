//
//  CircuitDiagrams.swift
//  F1Widget
//
//  Fetches and renders accurate F1 circuit outlines from the bacinger/f1-circuits
//  GeoJSON dataset (MIT-licensed). The track is drawn programmatically as a
//  SwiftUI Path, normalized to fit the available view space while preserving
//  the circuit's actual lat/lon aspect ratio.
//

import SwiftUI

// MARK: - jolpica circuit ID → bacinger file

enum CircuitDiagrams {

    static func url(forCircuitId id: String) -> URL? {
        guard let file = map[id] else { return nil }
        return URL(string: "https://raw.githubusercontent.com/bacinger/f1-circuits/master/circuits/\(file).geojson")
    }

    /// Standalone fetch + parse, usable from a widget TimelineProvider (no MainActor).
    static func fetchCoords(circuitId: String) async -> [CGPoint]? {
        guard let url = url(forCircuitId: circuitId) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let geo = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
            guard let coords = geo.features.first?.geometry.coordinates, !coords.isEmpty else { return nil }
            return coords.map { CGPoint(x: $0[0], y: $0[1]) }
        } catch {
            return nil
        }
    }

    private static let map: [String: String] = [
        "albert_park":   "au-1953",
        "americas":      "us-2012",
        "bahrain":       "bh-2002",
        "baku":          "az-2016",
        "catalunya":     "es-1991",
        "hungaroring":   "hu-1986",
        "imola":         "it-1953",
        "interlagos":    "br-1977",
        "jeddah":        "sa-2021",
        "losail":        "qa-2004",
        "marina_bay":    "sg-2008",
        "miami":         "us-2022",
        "monaco":        "mc-1929",
        "monza":         "it-1922",
        "red_bull_ring": "at-1969",
        "ricard":        "fr-1969",
        "rodriguez":     "mx-1962",
        "shanghai":      "cn-2004",
        "silverstone":   "gb-1948",
        "spa":           "be-1925",
        "suzuka":        "jp-1962",
        "vegas":         "us-2023",
        "villeneuve":    "ca-1978",
        "yas_marina":    "ae-2009",
        "zandvoort":     "nl-1948"
    ]
}

// MARK: - GeoJSON decoding

struct GeoJSONFeatureCollection: Decodable {
    let features: [GeoJSONFeature]
}

struct GeoJSONFeature: Decodable {
    let geometry: GeoJSONGeometry
}

struct GeoJSONGeometry: Decodable {
    let type: String
    let coordinates: [[Double]]
}

// MARK: - Cache

@MainActor
@Observable
final class CircuitDiagramCache {
    static let shared = CircuitDiagramCache()

    /// Cached track coordinates per circuit ID. Each CGPoint stores x = lon, y = lat.
    var coords: [String: [CGPoint]] = [:]
    var loading: Set<String> = []

    func load(circuitId: String) async {
        if coords[circuitId] != nil || loading.contains(circuitId) { return }
        guard let url = CircuitDiagrams.url(forCircuitId: circuitId) else { return }
        loading.insert(circuitId)
        defer { loading.remove(circuitId) }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let geo = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
            guard let raw = geo.features.first?.geometry.coordinates, !raw.isEmpty else { return }
            coords[circuitId] = raw.map { CGPoint(x: $0[0], y: $0[1]) }
        } catch {
            // Silent failure; the view will show empty.
        }
    }
}

// MARK: - Track view

struct CircuitTrackView: View {
    let circuitId: String
    /// If provided, use these coords directly instead of fetching (useful for widgets
    /// where the provider preloads the GeoJSON into the timeline entry).
    var prepopulated: [CGPoint]? = nil
    var strokeColor: Color = .white
    var lineWidth: CGFloat = 2.5
    var padding: CGFloat = 10

    private var cache: CircuitDiagramCache { .shared }

    var body: some View {
        GeometryReader { geo in
            let pts = prepopulated ?? cache.coords[circuitId] ?? []
            ZStack {
                if !pts.isEmpty {
                    trackPath(points: pts, in: geo.size)
                        .stroke(
                            strokeColor,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                }
            }
        }
        .task {
            if prepopulated == nil { await cache.load(circuitId: circuitId) }
        }
    }

    private func trackPath(points pts: [CGPoint], in size: CGSize) -> Path {
        let xs = pts.map(\.x)
        let ys = pts.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return Path() }
        let dx = max(maxX - minX, 0.000001)
        let dy = max(maxY - minY, 0.000001)

        let availW = max(size.width - padding * 2, 1)
        let availH = max(size.height - padding * 2, 1)
        // Fit to the smaller dimension to preserve aspect.
        let scale = min(availW / dx, availH / dy)
        let drawnW = dx * scale
        let drawnH = dy * scale
        let originX = padding + (availW - drawnW) / 2
        let originY = padding + (availH - drawnH) / 2

        func mapPoint(_ p: CGPoint) -> CGPoint {
            let x = originX + (p.x - minX) * scale
            // Flip Y because lat grows upward but view coords grow downward.
            let y = originY + (drawnH - (p.y - minY) * scale)
            return CGPoint(x: x, y: y)
        }

        var path = Path()
        path.move(to: mapPoint(pts[0]))
        for p in pts.dropFirst() {
            path.addLine(to: mapPoint(p))
        }
        return path
    }
}
