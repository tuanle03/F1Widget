//
//  F1Provider.swift
//  F1WidgetExtension
//
//  TimelineProvider: loads data for the widget and decides when to reload.
//

import WidgetKit
import SwiftUI

// MARK: - Entry (one frame of the timeline)

struct F1Entry: TimelineEntry {
    let date: Date
    let weekend: RaceWeekend?
    let standings: [DriverStanding]
    let constructorStandings: [ConstructorStanding]
    let trackPoints: [CGPoint]?      // preloaded circuit outline for the current weekend
    let errorMessage: String?

    static let placeholder = F1Entry(
        date: Date(),
        weekend: nil,
        standings: [],
        constructorStandings: [],
        trackPoints: nil,
        errorMessage: nil
    )
}

// MARK: - Provider

struct F1Provider: TimelineProvider {

    func placeholder(in context: Context) -> F1Entry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (F1Entry) -> Void) {
        // Quick preview in the gallery: try to fetch, fall back to placeholder on error.
        Task {
            let entry = await loadEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<F1Entry>) -> Void) {
        Task {
            let entry = await loadEntry()
            // Smart reload: if a session is starting within the next hour,
            // refresh sooner (15 min) to update status; otherwise 30 min.
            let now = Date()
            var refreshIn: TimeInterval = 30 * 60
            if let next = entry.weekend?.nextSession(after: now),
               next.start.timeIntervalSince(now) < 3600 {
                refreshIn = 15 * 60
            }
            let nextReload = now.addingTimeInterval(refreshIn)
            let timeline = Timeline(entries: [entry], policy: .after(nextReload))
            completion(timeline)
        }
    }

    // MARK: - Load

    private func loadEntry() async -> F1Entry {
        do {
            async let snapshotTask = F1API.fetchSnapshot()
            async let constructorTask = try? await F1API.fetchConstructorStandings()
            let snapshot = try await snapshotTask
            let constructors = await constructorTask ?? []
            let weekend = snapshot.upcomingWeekend()
            // Preload track outline so it renders immediately on first paint.
            var track: [CGPoint]? = nil
            if let weekend {
                track = await CircuitDiagrams.fetchCoords(circuitId: weekend.circuitId)
            }
            return F1Entry(
                date: Date(),
                weekend: weekend,
                standings: snapshot.standings,
                constructorStandings: constructors,
                trackPoints: track,
                errorMessage: nil
            )
        } catch {
            return F1Entry(
                date: Date(),
                weekend: nil,
                standings: [],
                constructorStandings: [],
                trackPoints: nil,
                errorMessage: "Could not load F1 data"
            )
        }
    }
}
