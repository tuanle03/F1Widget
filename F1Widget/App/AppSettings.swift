//
//  AppSettings.swift
//  F1Widget
//
//  Persistent user-tunable settings backed by UserDefaults.
//  Views read these via @AppStorage; non-view code reads/writes via this enum.
//

import Foundation

enum AppSettingsKey {
    static let showInMenuBar           = "showInMenuBar"
    static let showCountdownInMenuBar  = "showCountdownInMenuBar"
    static let notificationsEnabled    = "notificationsEnabled"
    static let notificationLeadMinutes = "notificationLeadMinutes"
    static let notifySessionFilter     = "notifySessionFilter"
}

enum AppSettings {
    static var showInMenuBar: Bool {
        if UserDefaults.standard.object(forKey: AppSettingsKey.showInMenuBar) == nil { return true }
        return UserDefaults.standard.bool(forKey: AppSettingsKey.showInMenuBar)
    }
    static var showCountdownInMenuBar: Bool {
        if UserDefaults.standard.object(forKey: AppSettingsKey.showCountdownInMenuBar) == nil { return true }
        return UserDefaults.standard.bool(forKey: AppSettingsKey.showCountdownInMenuBar)
    }
    static var notificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppSettingsKey.notificationsEnabled)
    }
    static var notificationLeadMinutes: Int {
        let raw = UserDefaults.standard.integer(forKey: AppSettingsKey.notificationLeadMinutes)
        return raw == 0 ? 15 : raw
    }
    static var notifySessionFilter: SessionFilter {
        let raw = UserDefaults.standard.string(forKey: AppSettingsKey.notifySessionFilter) ?? SessionFilter.qualifyingAndRace.rawValue
        return SessionFilter(rawValue: raw) ?? .qualifyingAndRace
    }
}

enum SessionFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case qualifyingAndRace = "qualifyingAndRace"
    case raceOnly = "raceOnly"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All sessions"
        case .qualifyingAndRace: return "Qualifying + Race"
        case .raceOnly: return "Race only"
        }
    }

    func matches(_ kind: SessionKind) -> Bool {
        switch self {
        case .all:
            return true
        case .qualifyingAndRace:
            return kind == .qualifying || kind == .grandPrix
                || kind == .sprintQuali || kind == .sprint
        case .raceOnly:
            return kind == .grandPrix || kind == .sprint
        }
    }
}
