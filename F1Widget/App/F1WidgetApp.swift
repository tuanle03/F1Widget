//
//  F1WidgetApp.swift
//  F1Widget (host app)
//
//  Host app for the macOS widget extension.
//  Provides a full F1 dashboard: Schedule, Results, and Standings (WDC + WCC).
//

import SwiftUI

@main
struct F1WidgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Theme

enum AppTheme {
    static let red       = Color(red: 0.882, green: 0.024, blue: 0.0)
    static let card      = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let cardHover = Color(red: 0.14, green: 0.14, blue: 0.16)
    static let subtle    = Color.white.opacity(0.55)
    static let divider   = Color.white.opacity(0.10)
    static let background = Color(red: 0.06, green: 0.06, blue: 0.07)
}

// MARK: - Dashboard state

@MainActor
@Observable
final class DashboardModel {
    var weekends: [RaceWeekend] = []
    var driverStandings: [DriverStanding] = []
    var constructorStandings: [ConstructorStanding] = []
    var isLoading = false
    var errorMessage: String?
    var lastLoaded: Date?

    // Cache of per-round results: keyed by "\(season)-\(round)-\(kind)".
    var resultsCache: [String: RaceWithResults] = [:]
    var loadingRounds: Set<String> = []

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let weekendsTask = F1API.fetchSchedule()
            async let driversTask = F1API.fetchDriverStandings()
            async let constructorsTask = F1API.fetchConstructorStandings()
            let (w, d, c) = try await (weekendsTask, driversTask, constructorsTask)
            weekends = w
            driverStandings = d
            constructorStandings = c
            errorMessage = nil
            lastLoaded = Date()
        } catch {
            errorMessage = "Could not load F1 data. Check your internet connection."
        }
    }

    enum ResultKind: String { case race, qualifying, sprint }

    func cacheKey(season: String, round: String, kind: ResultKind) -> String {
        "\(season)-\(round)-\(kind.rawValue)"
    }

    func loadResult(season: String, round: String, kind: ResultKind) async {
        let key = cacheKey(season: season, round: round, kind: kind)
        if resultsCache[key] != nil || loadingRounds.contains(key) { return }
        loadingRounds.insert(key)
        defer { loadingRounds.remove(key) }
        do {
            let result: RaceWithResults?
            switch kind {
            case .race:       result = try await F1API.fetchRaceResult(season: season, round: round)
            case .qualifying: result = try await F1API.fetchQualifyingResult(season: season, round: round)
            case .sprint:     result = try await F1API.fetchSprintResult(season: season, round: round)
            }
            if let result { resultsCache[key] = result }
        } catch {
            // Silent failure per-round; user can retry by re-tapping.
        }
    }
}

// MARK: - Root view

struct ContentView: View {
    @State private var model = DashboardModel()
    @State private var tab: Tab = .schedule

    enum Tab: String, CaseIterable, Identifiable {
        case schedule = "Schedule"
        case results  = "Results"
        case standings = "Standings"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .schedule:  return "calendar"
            case .results:   return "flag.checkered"
            case .standings: return "trophy"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().background(AppTheme.divider)
            content
        }
        .frame(width: 720, height: 820)
        .background(AppTheme.background)
        .foregroundStyle(.white)
        .task { if model.weekends.isEmpty { await model.loadAll() } }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("🏁").font(.title2)
            VStack(alignment: .leading, spacing: 0) {
                Text("F1 Dashboard")
                    .font(.title3.bold())
                if let lastLoaded = model.lastLoaded {
                    Text("Updated \(lastLoaded.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.subtle)
                }
            }
            Spacer()
            Button(action: { Task { await model.loadAll() } }) {
                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .disabled(model.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases) { t in
                Button { tab = t } label: {
                    HStack(spacing: 6) {
                        Image(systemName: t.icon).font(.caption)
                        Text(t.rawValue).font(.callout.weight(.medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(tab == t ? AppTheme.red : AppTheme.card)
                    )
                    .foregroundStyle(tab == t ? .white : AppTheme.subtle)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if model.errorMessage != nil && model.weekends.isEmpty {
            errorState
        } else if model.weekends.isEmpty && model.isLoading {
            loadingState
        } else {
            switch tab {
            case .schedule:  ScheduleView(model: model)
            case .results:   ResultsView(model: model)
            case .standings: StandingsView(model: model)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Loading F1 data…")
                .font(.caption)
                .foregroundStyle(AppTheme.subtle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.red)
            Text(model.errorMessage ?? "Unknown error")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try again") { Task { await model.loadAll() } }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Schedule tab

struct ScheduleView: View {
    @Bindable var model: DashboardModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let weekend = upcoming {
                    WeekendHeroCard(weekend: weekend)
                    SessionsCard(weekend: weekend)
                    if let nextRace = upcomingAfter(weekend) {
                        UpNextCard(weekend: nextRace)
                    }
                } else {
                    Text("No upcoming race found.")
                        .foregroundStyle(AppTheme.subtle)
                }
                footer
            }
            .padding(20)
        }
    }

    private var upcoming: RaceWeekend? {
        F1Snapshot(weekends: model.weekends, standings: model.driverStandings)
            .upcomingWeekend()
    }

    private func upcomingAfter(_ w: RaceWeekend) -> RaceWeekend? {
        guard let idx = model.weekends.firstIndex(where: { $0.id == w.id }) else { return nil }
        return model.weekends.dropFirst(idx + 1).first
    }

    private var footer: some View {
        Text("Data: jolpica-f1 API (Ergast-compatible). Times shown in your local time zone.")
            .font(.caption2)
            .foregroundStyle(AppTheme.subtle)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}

private struct WeekendHeroCard: View {
    let weekend: RaceWeekend

    var body: some View {
        let next = weekend.nextSession(after: Date())
        ZStack(alignment: .topLeading) {
            CountryGradient.gradient(for: weekend.country)
                .overlay(Color.black.opacity(0.50))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 14) {
                // Top info row
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ROUND \(weekend.round)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Capsule().fill(AppTheme.red))
                        Text(weekend.name)
                            .font(.system(size: 30, weight: .heavy))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: 6) {
                            Text(weekend.countryFlag).font(.title3)
                            Text("\(weekend.locality), \(weekend.country)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Text(weekend.circuitName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Text(weekend.countryFlag)
                        .font(.system(size: 64))
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                }

                // Map satellite + track diagram, side by side
                HStack(spacing: 10) {
                    CircuitMapView(circuitId: weekend.circuitId)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    CircuitTrackView(circuitId: weekend.circuitId,
                                     strokeColor: AppTheme.red,
                                     lineWidth: 2.5)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.30))
                        )
                }

                if let next {
                    Divider().background(AppTheme.divider)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEXT SESSION")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            Text(next.kind.rawValue)
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(next.start, style: .relative)
                                .font(.title2.bold().monospacedDigit())
                                .foregroundStyle(AppTheme.red)
                            Text(next.start.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                } else {
                    Divider().background(AppTheme.divider)
                    Text("Weekend complete")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SessionsCard: View {
    let weekend: RaceWeekend

    var body: some View {
        let next = weekend.nextSession(after: Date())
        CardSection(title: "SESSIONS") {
            VStack(spacing: 8) {
                ForEach(weekend.sessions) { s in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(s.id == next?.id ? AppTheme.red : Color.clear)
                            .frame(width: 3, height: 18)
                        Text(s.kind.rawValue)
                            .font(.callout)
                            .fontWeight(s.id == next?.id ? .semibold : .regular)
                        Spacer()
                        Text(s.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtle)
                        Text(s.start.formatted(date: .omitted, time: .shortened))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(s.id == next?.id ? AppTheme.red : .white)
                            .frame(width: 72, alignment: .trailing)
                    }
                }
            }
        }
    }
}

private struct UpNextCard: View {
    let weekend: RaceWeekend
    var body: some View {
        CardSection(title: "AFTER THIS WEEKEND") {
            HStack(spacing: 12) {
                Text(weekend.countryFlag).font(.system(size: 36))
                VStack(alignment: .leading, spacing: 2) {
                    Text(weekend.name).font(.callout.weight(.semibold))
                    Text("\(weekend.locality), \(weekend.country) • R\(weekend.round)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtle)
                }
                Spacer()
                if let date = weekend.raceDate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(date.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.callout.weight(.semibold))
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtle)
                    }
                }
            }
        }
    }
}

// MARK: - Results tab

struct ResultsView: View {
    @Bindable var model: DashboardModel
    @State private var expandedRoundId: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(completed) { weekend in
                    RaceResultsCard(
                        weekend: weekend,
                        isExpanded: expandedRoundId == weekend.id,
                        model: model,
                        onToggle: {
                            withAnimation(.snappy(duration: 0.25)) {
                                expandedRoundId = expandedRoundId == weekend.id ? nil : weekend.id
                            }
                        }
                    )
                }
                if completed.isEmpty {
                    Text("No completed races yet this season.")
                        .foregroundStyle(AppTheme.subtle)
                        .padding(.top, 60)
                }
            }
            .padding(20)
        }
    }

    private var completed: [RaceWeekend] {
        model.weekends.filter(\.isCompleted).reversed()
    }
}

private struct RaceResultsCard: View {
    let weekend: RaceWeekend
    let isExpanded: Bool
    @Bindable var model: DashboardModel
    let onToggle: () -> Void

    @State private var resultTab: DashboardModel.ResultKind = .race

    var body: some View {
        VStack(spacing: 0) {
            // Header row (clickable)
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Text(weekend.countryFlag).font(.system(size: 36))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekend.name).font(.callout.weight(.semibold))
                        Text("\(weekend.locality)  •  Round \(weekend.round)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtle)
                    }
                    Spacer()
                    if let date = weekend.raceDate {
                        Text(date.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.callout.weight(.medium))
                            .foregroundStyle(AppTheme.subtle)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AppTheme.subtle)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(AppTheme.divider)
                VStack(spacing: 12) {
                    resultTabsPicker
                    resultContent
                }
                .padding(16)
            }
        }
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }

    private var resultTabsPicker: some View {
        HStack(spacing: 6) {
            ForEach(visibleResultKinds, id: \.self) { kind in
                Button {
                    resultTab = kind
                    Task { await model.loadResult(season: weekend.season,
                                                  round: weekend.round,
                                                  kind: kind) }
                } label: {
                    Text(label(for: kind))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(resultTab == kind ? AppTheme.red : Color.white.opacity(0.06)))
                        .foregroundStyle(resultTab == kind ? .white : AppTheme.subtle)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var visibleResultKinds: [DashboardModel.ResultKind] {
        weekend.hasSprint ? [.race, .qualifying, .sprint] : [.race, .qualifying]
    }

    private func label(for kind: DashboardModel.ResultKind) -> String {
        switch kind {
        case .race: return "Race"
        case .qualifying: return "Qualifying"
        case .sprint: return "Sprint"
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        let key = model.cacheKey(season: weekend.season, round: weekend.round, kind: resultTab)
        if let cached = model.resultsCache[key] {
            switch resultTab {
            case .race:
                RaceResultsTable(rows: (cached.results ?? []).map(RaceResultRow.init))
            case .qualifying:
                QualifyingTable(rows: cached.qualifyingResults ?? [])
            case .sprint:
                RaceResultsTable(rows: (cached.sprintResults ?? []).map(RaceResultRow.init))
            }
        } else if model.loadingRounds.contains(key) {
            ProgressView().padding(.vertical, 20)
        } else {
            Button("Load results") {
                Task { await model.loadResult(season: weekend.season,
                                              round: weekend.round,
                                              kind: resultTab) }
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.red)
            .onAppear {
                Task { await model.loadResult(season: weekend.season,
                                              round: weekend.round,
                                              kind: resultTab) }
            }
        }
    }
}

private struct RaceResultRow {
    let position: String
    let driver: Driver
    let constructor: Constructor
    let points: String
    let time: String?
    let status: String

    init(_ r: RaceResult) {
        position = r.position
        driver = r.driver
        constructor = r.constructor
        points = r.points
        time = r.time?.time
        status = r.status
    }
}

private struct RaceResultsTable: View {
    let rows: [RaceResultRow]
    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 10) {
                    PositionPill(position: r.position)
                    TeamBadge(constructorId: r.constructor.constructorId, size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(r.driver.givenName) \(r.driver.familyName)")
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Text(r.constructor.name)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtle)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let time = r.time, !time.isEmpty {
                        Text(time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.subtle)
                    } else {
                        Text(r.status)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtle)
                    }
                    Text("\(r.points)")
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct QualifyingTable: View {
    let rows: [QualifyingResult]
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Text("").frame(width: 30)
                Text("").frame(width: 30)
                Text("Driver").font(.caption2.weight(.semibold)).foregroundStyle(AppTheme.subtle)
                Spacer()
                Group {
                    Text("Q1").frame(width: 64, alignment: .trailing)
                    Text("Q2").frame(width: 64, alignment: .trailing)
                    Text("Q3").frame(width: 64, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.subtle)
            }
            ForEach(rows) { r in
                HStack(spacing: 10) {
                    PositionPill(position: r.position)
                    TeamBadge(constructorId: r.constructor.constructorId, size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(r.driver.givenName) \(r.driver.familyName)")
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Text(r.constructor.name)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtle)
                            .lineLimit(1)
                    }
                    Spacer()
                    Group {
                        Text(r.q1 ?? "—").frame(width: 64, alignment: .trailing)
                        Text(r.q2 ?? "—").frame(width: 64, alignment: .trailing)
                        Text(r.q3 ?? "—").frame(width: 64, alignment: .trailing)
                    }
                    .font(.caption.monospacedDigit())
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Standings tab

struct StandingsView: View {
    @Bindable var model: DashboardModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                wdcSection
                wccSection
            }
            .padding(20)
        }
    }

    private var wdcSection: some View {
        CardSection(title: "WDC – World Drivers' Championship") {
            VStack(spacing: 6) {
                ForEach(model.driverStandings) { d in
                    HStack(spacing: 12) {
                        Text(d.position)
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .foregroundStyle(AppTheme.subtle)
                            .frame(width: 24, alignment: .trailing)
                        TeamBadge(constructorId: d.constructors.first?.constructorId ?? "", size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(d.driver.givenName) \(d.driver.familyName)")
                                .font(.callout.weight(.semibold))
                            Text(d.constructors.first?.name ?? "")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtle)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(d.points)
                                .font(.callout.monospacedDigit().weight(.bold))
                            Text("\(d.wins) wins")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtle)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    private var wccSection: some View {
        CardSection(title: "WCC – World Constructors' Championship") {
            VStack(spacing: 6) {
                ForEach(model.constructorStandings) { c in
                    HStack(spacing: 12) {
                        Text(c.position)
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .foregroundStyle(AppTheme.subtle)
                            .frame(width: 24, alignment: .trailing)
                        TeamBadge(constructorId: c.constructor.constructorId, size: 36)
                        Text(c.constructor.name)
                            .font(.callout.weight(.semibold))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(c.points)
                                .font(.callout.monospacedDigit().weight(.bold))
                            Text("\(c.wins) wins")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtle)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }
}

// MARK: - Position pill (gold/silver/bronze for top 3)

struct PositionPill: View {
    let position: String

    var body: some View {
        let pos = Int(position) ?? 0
        let (bg, fg) = colors(for: pos)
        Text(position)
            .font(.callout.monospacedDigit().weight(.heavy))
            .foregroundStyle(fg)
            .frame(width: 30, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(bg)
            )
    }

    private func colors(for pos: Int) -> (Color, Color) {
        switch pos {
        case 1: return (Color(red: 0.98, green: 0.82, blue: 0.25), .black)
        case 2: return (Color(red: 0.78, green: 0.78, blue: 0.80), .black)
        case 3: return (Color(red: 0.80, green: 0.50, blue: 0.20), .black)
        default: return (Color.white.opacity(0.06), .white.opacity(0.75))
        }
    }
}

// MARK: - Reusable card section

struct CardSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.subtle)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
