//
//  F1WidgetViews.swift
//  F1WidgetExtension
//
//  Widget UI for three sizes: small / medium / large.
//

import WidgetKit
import SwiftUI

// MARK: - Theme

enum F1Theme {
    static let red = Color(red: 0.882, green: 0.024, blue: 0.0)
    static let card = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let subtle = Color.white.opacity(0.55)
    static let divider = Color.white.opacity(0.10)
}

// MARK: - Shared formatters

enum F1Format {
    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

struct CountdownText: View {
    let target: Date
    var body: some View {
        if target.timeIntervalSinceNow < 3600 && target.timeIntervalSinceNow > 0 {
            Text(target, style: .timer).monospacedDigit()
        } else {
            Text(target, style: .relative)
        }
    }
}

// MARK: - Empty / Error state

struct F1EmptyView: View {
    let message: String
    var body: some View {
        VStack(spacing: 6) {
            Text("🏁").font(.title)
            Text(message)
                .font(.caption)
                .foregroundStyle(F1Theme.subtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compact session row

struct CompactSessionRow: View {
    let session: RaceSession
    let isNext: Bool
    var showWeekday: Bool = true
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isNext ? F1Theme.red : Color.clear)
                .frame(width: 2.5, height: 11)
            Text(session.kind.shortLabel)
                .font(.caption2)
                .fontWeight(isNext ? .semibold : .regular)
                .foregroundStyle(isNext ? .white : .white.opacity(0.85))
                .frame(width: 34, alignment: .leading)
            if showWeekday {
                Text(F1Format.weekday(session.start))
                    .font(.caption2)
                    .foregroundStyle(F1Theme.subtle)
            }
            Spacer(minLength: 2)
            Text(F1Format.time(session.start))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isNext ? F1Theme.red : .white)
        }
    }
}

// MARK: - SMALL widget

struct SmallWidgetView: View {
    let entry: F1Entry
    var body: some View {
        Group {
            if let w = entry.weekend {
                let next = w.nextSession(after: entry.date)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(w.countryFlag).font(.title3)
                        Spacer()
                        Text("R\(w.round)")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(F1Theme.red))
                    }
                    Text(w.name)
                        .font(.caption.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    // Give the track an explicit min height so it survives layout pressure.
                    CircuitTrackView(circuitId: w.circuitId,
                                     prepopulated: entry.trackPoints,
                                     strokeColor: F1Theme.red,
                                     lineWidth: 1.8,
                                     padding: 2)
                        .frame(minHeight: 50, maxHeight: .infinity)
                    if let next {
                        Text(next.kind.rawValue.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(F1Theme.red)
                            .lineLimit(1)
                        CountdownText(target: next.start)
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text("Season ended")
                            .font(.caption2).foregroundStyle(F1Theme.subtle)
                    }
                }
            } else {
                F1EmptyView(message: entry.errorMessage ?? "Loading…")
            }
        }
    }
}

// MARK: - MEDIUM widget (track | sessions)

struct MediumWidgetView: View {
    let entry: F1Entry
    var body: some View {
        Group {
            if let w = entry.weekend {
                let next = w.nextSession(after: entry.date)
                VStack(alignment: .leading, spacing: 4) {
                    // Header
                    HStack(alignment: .top, spacing: 6) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(w.name)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("\(w.locality) · R\(w.round)")
                                .font(.caption2)
                                .foregroundStyle(F1Theme.subtle)
                        }
                        Spacer(minLength: 4)
                        Text(w.countryFlag).font(.title3)
                    }
                    // Two columns: track | sessions
                    HStack(alignment: .top, spacing: 12) {
                        CircuitTrackView(circuitId: w.circuitId,
                                         prepopulated: entry.trackPoints,
                                         strokeColor: F1Theme.red,
                                         lineWidth: 2,
                                         padding: 4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        VStack(spacing: 4) {
                            ForEach(w.sessions.suffix(4)) { s in
                                CompactSessionRow(session: s, isNext: s.id == next?.id)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if let next {
                        HStack(spacing: 4) {
                            Text("NEXT: \(next.kind.shortLabel) in")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(F1Theme.subtle)
                            CountdownText(target: next.start)
                                .font(.caption2.bold().monospacedDigit())
                                .foregroundStyle(F1Theme.red)
                        }
                    }
                }
            } else {
                F1EmptyView(message: entry.errorMessage ?? "Loading…")
            }
        }
    }
}

// MARK: - LARGE widget (track | sessions, then standings below)

struct LargeWidgetView: View {
    let entry: F1Entry
    var body: some View {
        Group {
            if let w = entry.weekend {
                let next = w.nextSession(after: entry.date)
                VStack(alignment: .leading, spacing: 6) {
                    // Header
                    HStack(alignment: .top, spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(w.name)
                                .font(.headline.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("\(w.locality), \(w.country) · Round \(w.round)")
                                .font(.caption2)
                                .foregroundStyle(F1Theme.subtle)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text(w.countryFlag).font(.title)
                    }
                    // Two columns: track | sessions
                    HStack(alignment: .top, spacing: 12) {
                        CircuitTrackView(circuitId: w.circuitId,
                                         prepopulated: entry.trackPoints,
                                         strokeColor: F1Theme.red,
                                         lineWidth: 2.2,
                                         padding: 6)
                            .frame(height: 110)
                            .frame(maxWidth: .infinity)
                        VStack(spacing: 4) {
                            ForEach(w.sessions) { s in
                                CompactSessionRow(session: s, isNext: s.id == next?.id)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if let next {
                        HStack(spacing: 6) {
                            Image(systemName: "flag.checkered")
                                .font(.caption2).foregroundStyle(F1Theme.red)
                            Text("NEXT: \(next.kind.rawValue)")
                                .font(.caption2).foregroundStyle(.white)
                            Spacer()
                            CountdownText(target: next.start)
                                .font(.caption2.bold().monospacedDigit())
                                .foregroundStyle(F1Theme.red)
                        }
                    }
                    Divider().overlay(F1Theme.divider)
                    Text("DRIVER STANDINGS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(F1Theme.subtle)
                    VStack(spacing: 3) {
                        ForEach(entry.standings.prefix(5)) { d in
                            HStack(spacing: 6) {
                                Text(d.position)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(F1Theme.subtle)
                                    .frame(width: 12, alignment: .trailing)
                                TeamBadge(constructorId: d.constructors.first?.constructorId ?? "", size: 16)
                                Text(d.driver.familyName)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(d.points) pts")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                F1EmptyView(message: entry.errorMessage ?? "Loading…")
            }
        }
    }
}
