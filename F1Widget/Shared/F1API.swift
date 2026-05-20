//
//  F1API.swift
//  F1Widget
//
//  Networking layer that calls jolpica-f1 and normalizes the data.
//  Uses async/await + URLSession.
//
//  macOS NOTE: the widget extension runs inside the sandbox; you MUST enable the
//  "Outgoing Connections (Client)" entitlement (com.apple.security.network.client)
//  on both the host app and the widget target, otherwise every request is blocked.
//

import Foundation

struct F1API {

    private static let base = "https://api.jolpi.ca/ergast/f1"

    // UTC time format from the API: combines "yyyy-MM-dd" + "HH:mm:ssZ".
    private static let utcFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Snapshot (used by the widget)

    /// Fetch the current season schedule + driver standings, wrapped as a widget snapshot.
    static func fetchSnapshot() async throws -> F1Snapshot {
        async let weekends = fetchSchedule()
        async let standings = fetchDriverStandings()
        return F1Snapshot(weekends: try await weekends,
                          standings: (try? await standings) ?? [])
    }

    // MARK: - Schedule

    static func fetchSchedule() async throws -> [RaceWeekend] {
        let url = URL(string: "\(base)/current.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(ScheduleResponse.self, from: data)
        return decoded.mrData.raceTable.races.map(makeWeekend)
    }

    // MARK: - Standings

    static func fetchDriverStandings() async throws -> [DriverStanding] {
        let url = URL(string: "\(base)/current/driverStandings.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(DriverStandingsResponse.self, from: data)
        return decoded.mrData.standingsTable.standingsLists.first?.driverStandings ?? []
    }

    static func fetchConstructorStandings() async throws -> [ConstructorStanding] {
        let url = URL(string: "\(base)/current/constructorStandings.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(ConstructorStandingsResponse.self, from: data)
        return decoded.mrData.standingsTable.standingsLists.first?.constructorStandings ?? []
    }

    // MARK: - Results per race

    static func fetchRaceResult(season: String, round: String) async throws -> RaceWithResults? {
        try await fetchResultsEndpoint(path: "\(season)/\(round)/results.json")
    }

    static func fetchQualifyingResult(season: String, round: String) async throws -> RaceWithResults? {
        try await fetchResultsEndpoint(path: "\(season)/\(round)/qualifying.json")
    }

    static func fetchSprintResult(season: String, round: String) async throws -> RaceWithResults? {
        try await fetchResultsEndpoint(path: "\(season)/\(round)/sprint.json")
    }

    private static func fetchResultsEndpoint(path: String) async throws -> RaceWithResults? {
        let url = URL(string: "\(base)/\(path)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(ResultsResponse.self, from: data)
        return decoded.mrData.raceTable.races.first
    }

    // MARK: - Mapping helpers

    private static func makeWeekend(_ race: Race) -> RaceWeekend {
        var sessions: [RaceSession] = []

        func add(_ kind: SessionKind, _ stub: SessionStub?) {
            guard let stub, let date = parseDate(stub) else { return }
            sessions.append(RaceSession(kind: kind, start: date))
        }

        add(.fp1, race.firstPractice)
        add(.fp2, race.secondPractice)
        add(.fp3, race.thirdPractice)
        add(.sprintQuali, race.sprintQualifying)
        add(.sprint, race.sprint)
        add(.qualifying, race.qualifying)

        // Grand Prix: combine the Race's own date + time.
        let gpDate = parseDate(SessionStub(date: race.date, time: race.time))
        if let gp = gpDate {
            sessions.append(RaceSession(kind: .grandPrix, start: gp))
        }

        sessions.sort { $0.start < $1.start }

        return RaceWeekend(
            round: race.round,
            season: race.season,
            name: race.raceName,
            locality: race.circuit.location.locality,
            country: race.circuit.location.country,
            countryFlag: CountryFlags.flag(for: race.circuit.location.country),
            circuitId: race.circuit.circuitId,
            circuitName: race.circuit.circuitName,
            raceDate: gpDate,
            sessions: sessions
        )
    }

    /// Combine "yyyy-MM-dd" + "HH:mm:ssZ" into a Date (UTC). If the time is missing -> default 00:00Z.
    private static func parseDate(_ stub: SessionStub) -> Date? {
        let time = stub.time ?? "00:00:00Z"
        let iso = "\(stub.date)T\(time)"
        return utcFormatter.date(from: iso)
    }
}

// MARK: - Aggregated snapshot for the widget

struct F1Snapshot {
    let weekends: [RaceWeekend]
    let standings: [DriverStanding]

    /// The next (or currently running) weekend relative to `now`.
    func upcomingWeekend(now: Date = Date()) -> RaceWeekend? {
        let upcoming = weekends.first { wknd in
            wknd.sessions.contains { $0.start > now }
        }
        return upcoming ?? weekends.last
    }

    static let placeholder = F1Snapshot(weekends: [], standings: [])
}
