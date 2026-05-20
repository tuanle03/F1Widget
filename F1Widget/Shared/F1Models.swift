//
//  F1Models.swift
//  F1Widget
//
//  Codable models for the jolpica-f1 API (Ergast-compatible JSON).
//  Base endpoint: https://api.jolpi.ca/ergast/f1/
//
//  Note: the API returns every numeric value as a String (legacy Ergast style),
//  so we keep them as String here and parse only when needed for display.
//

import Foundation

// MARK: - Schedule (season schedule)

struct ScheduleResponse: Decodable {
    let mrData: MRDataSchedule
    enum CodingKeys: String, CodingKey { case mrData = "MRData" }
}

struct MRDataSchedule: Decodable {
    let raceTable: RaceTable
    enum CodingKeys: String, CodingKey { case raceTable = "RaceTable" }
}

struct RaceTable: Decodable {
    let season: String
    let races: [Race]
    enum CodingKeys: String, CodingKey {
        case season
        case races = "Races"
    }
}

struct Race: Decodable, Identifiable {
    let season: String
    let round: String
    let raceName: String
    let circuit: Circuit
    let date: String          // "2026-03-08"
    let time: String?         // "04:00:00Z"

    let firstPractice: SessionStub?
    let secondPractice: SessionStub?
    let thirdPractice: SessionStub?
    let qualifying: SessionStub?
    let sprint: SessionStub?
    let sprintQualifying: SessionStub?

    var id: String { "\(season)-\(round)" }

    enum CodingKeys: String, CodingKey {
        case season, round, raceName, date, time
        case circuit = "Circuit"
        case firstPractice = "FirstPractice"
        case secondPractice = "SecondPractice"
        case thirdPractice = "ThirdPractice"
        case qualifying = "Qualifying"
        case sprint = "Sprint"
        case sprintQualifying = "SprintQualifying"
    }
}

struct Circuit: Decodable {
    let circuitId: String
    let circuitName: String
    let location: Location
    enum CodingKeys: String, CodingKey {
        case circuitId, circuitName
        case location = "Location"
    }
}

struct Location: Decodable {
    let locality: String
    let country: String
}

/// A raw timestamp from the API (date + UTC time).
struct SessionStub: Decodable {
    let date: String
    let time: String?
}

// MARK: - Driver Standings (WDC)

struct DriverStandingsResponse: Decodable {
    let mrData: MRDataStandings
    enum CodingKeys: String, CodingKey { case mrData = "MRData" }
}

struct MRDataStandings: Decodable {
    let standingsTable: StandingsTable
    enum CodingKeys: String, CodingKey { case standingsTable = "StandingsTable" }
}

struct StandingsTable: Decodable {
    let standingsLists: [StandingsList]
    enum CodingKeys: String, CodingKey { case standingsLists = "StandingsLists" }
}

struct StandingsList: Decodable {
    let season: String
    let round: String
    let driverStandings: [DriverStanding]
    enum CodingKeys: String, CodingKey {
        case season, round
        case driverStandings = "DriverStandings"
    }
}

struct DriverStanding: Decodable, Identifiable {
    let position: String
    let points: String
    let wins: String
    let driver: Driver
    let constructors: [Constructor]

    var id: String { driver.driverId }

    enum CodingKeys: String, CodingKey {
        case position, points, wins
        case driver = "Driver"
        case constructors = "Constructors"
    }
}

struct Driver: Decodable {
    let driverId: String
    let code: String?
    let permanentNumber: String?
    let givenName: String
    let familyName: String
}

struct Constructor: Decodable {
    let constructorId: String
    let name: String
    let nationality: String?
}

// MARK: - Constructor Standings (WCC)

struct ConstructorStandingsResponse: Decodable {
    let mrData: MRDataConstructorStandings
    enum CodingKeys: String, CodingKey { case mrData = "MRData" }
}

struct MRDataConstructorStandings: Decodable {
    let standingsTable: ConstructorStandingsTable
    enum CodingKeys: String, CodingKey { case standingsTable = "StandingsTable" }
}

struct ConstructorStandingsTable: Decodable {
    let standingsLists: [ConstructorStandingsList]
    enum CodingKeys: String, CodingKey { case standingsLists = "StandingsLists" }
}

struct ConstructorStandingsList: Decodable {
    let season: String
    let round: String
    let constructorStandings: [ConstructorStanding]
    enum CodingKeys: String, CodingKey {
        case season, round
        case constructorStandings = "ConstructorStandings"
    }
}

struct ConstructorStanding: Decodable, Identifiable {
    let position: String
    let points: String
    let wins: String
    let constructor: Constructor
    var id: String { constructor.constructorId }
    enum CodingKeys: String, CodingKey {
        case position, points, wins
        case constructor = "Constructor"
    }
}

// MARK: - Race Results (Race / Sprint / Qualifying)

struct ResultsResponse: Decodable {
    let mrData: MRDataResults
    enum CodingKeys: String, CodingKey { case mrData = "MRData" }
}

struct MRDataResults: Decodable {
    let raceTable: ResultsTable
    enum CodingKeys: String, CodingKey { case raceTable = "RaceTable" }
}

struct ResultsTable: Decodable {
    let races: [RaceWithResults]
    enum CodingKeys: String, CodingKey { case races = "Races" }
}

struct RaceWithResults: Decodable {
    let season: String
    let round: String
    let raceName: String
    let circuit: Circuit
    let date: String
    let results: [RaceResult]?
    let qualifyingResults: [QualifyingResult]?
    let sprintResults: [RaceResult]?
    enum CodingKeys: String, CodingKey {
        case season, round, raceName, date
        case circuit = "Circuit"
        case results = "Results"
        case qualifyingResults = "QualifyingResults"
        case sprintResults = "SprintResults"
    }
}

struct RaceResult: Decodable, Identifiable {
    let number: String
    let position: String
    let points: String
    let driver: Driver
    let constructor: Constructor
    let grid: String
    let laps: String
    let status: String
    let time: ResultTime?
    let fastestLap: FastestLap?
    var id: String { driver.driverId }
    enum CodingKeys: String, CodingKey {
        case number, position, points, grid, laps, status, time
        case driver = "Driver"
        case constructor = "Constructor"
        case fastestLap = "FastestLap"
    }
}

struct QualifyingResult: Decodable, Identifiable {
    let number: String
    let position: String
    let driver: Driver
    let constructor: Constructor
    let q1: String?
    let q2: String?
    let q3: String?
    var id: String { driver.driverId }
    enum CodingKeys: String, CodingKey {
        case number, position
        case driver = "Driver"
        case constructor = "Constructor"
        case q1 = "Q1"
        case q2 = "Q2"
        case q3 = "Q3"
    }
}

struct ResultTime: Decodable {
    let millis: String?
    let time: String
}

struct FastestLap: Decodable {
    let rank: String?
    let lap: String?
    let time: ResultTime?
}

// MARK: - View-ready intermediate types (with parsed Dates, ready to render)

enum SessionKind: String {
    case fp1 = "Practice 1"
    case fp2 = "Practice 2"
    case fp3 = "Practice 3"
    case sprintQuali = "Sprint Quali"
    case sprint = "Sprint"
    case qualifying = "Qualifying"
    case grandPrix = "Grand Prix"

    /// Short label for the small widget.
    var shortLabel: String {
        switch self {
        case .fp1: return "FP1"
        case .fp2: return "FP2"
        case .fp3: return "FP3"
        case .sprintQuali: return "SQ"
        case .sprint: return "Sprint"
        case .qualifying: return "Quali"
        case .grandPrix: return "Race"
        }
    }
}

/// A session with a real parsed Date (in UTC), ready to render.
struct RaceSession: Identifiable {
    let kind: SessionKind
    let start: Date
    var id: String { kind.rawValue }
}

/// All information about a race weekend, normalized for the widget.
struct RaceWeekend: Identifiable {
    let round: String
    let season: String
    let name: String           // "Australian Grand Prix"
    let locality: String       // "Melbourne"
    let country: String        // "Australia"
    let countryFlag: String    // flag emoji
    let circuitId: String
    let circuitName: String
    let raceDate: Date?
    let sessions: [RaceSession]

    var id: String { "\(season)-\(round)" }

    /// Time of the Grand Prix (main session). Used for scheduling / countdown.
    var grandPrixDate: Date? {
        sessions.first(where: { $0.kind == .grandPrix })?.start
    }

    /// The next upcoming session relative to `now` (including sessions later in the same weekend).
    func nextSession(after now: Date) -> RaceSession? {
        sessions
            .filter { $0.start > now }
            .sorted { $0.start < $1.start }
            .first
    }

    /// Whether the race is fully in the past.
    var isCompleted: Bool {
        guard let race = grandPrixDate else { return false }
        return race < Date()
    }

    /// Whether the race has a sprint format.
    var hasSprint: Bool {
        sessions.contains { $0.kind == .sprint }
    }
}
