//
//  CountryFlags.swift
//  F1Widget
//
//  Map country name (the API's `country` field) -> flag emoji.
//  The API returns country names in English, so we map by those English names.
//

import Foundation

enum CountryFlags {

    /// Return the flag emoji for a country name. Falls back to the checkered flag 🏁.
    static func flag(for country: String) -> String {
        table[country] ?? "🏁"
    }

    private static let table: [String: String] = [
        "Australia": "🇦🇺",
        "Austria": "🇦🇹",
        "Azerbaijan": "🇦🇿",
        "Bahrain": "🇧🇭",
        "Belgium": "🇧🇪",
        "Brazil": "🇧🇷",
        "Canada": "🇨🇦",
        "China": "🇨🇳",
        "France": "🇫🇷",
        "Germany": "🇩🇪",
        "Hungary": "🇭🇺",
        "Italy": "🇮🇹",
        "Japan": "🇯🇵",
        "Mexico": "🇲🇽",
        "Monaco": "🇲🇨",
        "Netherlands": "🇳🇱",
        "Portugal": "🇵🇹",
        "Qatar": "🇶🇦",
        "Russia": "🇷🇺",
        "Saudi Arabia": "🇸🇦",
        "Singapore": "🇸🇬",
        "Spain": "🇪🇸",
        "Turkey": "🇹🇷",
        "UAE": "🇦🇪",
        "United Arab Emirates": "🇦🇪",
        "UK": "🇬🇧",
        "United Kingdom": "🇬🇧",
        "United States": "🇺🇸",
        "USA": "🇺🇸",
        "Vietnam": "🇻🇳"
    ]
}
