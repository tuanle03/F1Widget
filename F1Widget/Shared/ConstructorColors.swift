//
//  ConstructorColors.swift
//  F1Widget
//
//  Maps jolpica constructor IDs to team color, short code, and logo URL.
//  Logos come from formula1.com's public media CDN.
//

import SwiftUI

struct ConstructorBrand {
    let color: Color
    let code: String           // 3-letter abbreviation (fallback when asset missing)
    let logoAsset: String?     // bundled image asset name (TeamLogos namespace)
}

enum ConstructorColors {

    static func brand(forConstructorId id: String) -> ConstructorBrand {
        let key = id.lowercased()
        if let b = table[key] { return b }
        for (k, v) in table where key.contains(k) { return v }
        return ConstructorBrand(color: .gray, code: String(id.prefix(3).uppercased()), logoAsset: nil)
    }

    static func color(forConstructorId id: String) -> Color {
        brand(forConstructorId: id).color
    }

    static func logoAsset(forConstructorId id: String) -> String? {
        brand(forConstructorId: id).logoAsset
    }

    private static let table: [String: ConstructorBrand] = [
        "mercedes":             .init(color: Color(red: 0.15, green: 0.85, blue: 0.78), code: "MER", logoAsset: "TeamLogos/mercedes"),
        "ferrari":              .init(color: Color(red: 0.91, green: 0.00, blue: 0.13), code: "FER", logoAsset: "TeamLogos/ferrari"),
        "red_bull":             .init(color: Color(red: 0.21, green: 0.44, blue: 0.78), code: "RBR", logoAsset: "TeamLogos/red-bull-racing"),
        "mclaren":              .init(color: Color(red: 1.00, green: 0.50, blue: 0.00), code: "MCL", logoAsset: "TeamLogos/mclaren"),
        "aston_martin":         .init(color: Color(red: 0.13, green: 0.55, blue: 0.46), code: "AST", logoAsset: "TeamLogos/aston-martin"),
        "alpine":               .init(color: Color(red: 0.13, green: 0.58, blue: 0.82), code: "ALP", logoAsset: "TeamLogos/alpine"),
        "alpine_f1_team":       .init(color: Color(red: 0.13, green: 0.58, blue: 0.82), code: "ALP", logoAsset: "TeamLogos/alpine"),
        "williams":             .init(color: Color(red: 0.16, green: 0.55, blue: 0.86), code: "WIL", logoAsset: "TeamLogos/williams"),
        "haas":                 .init(color: Color(red: 0.71, green: 0.73, blue: 0.74), code: "HAA", logoAsset: "TeamLogos/haas"),
        "sauber":               .init(color: Color(red: 0.00, green: 0.91, blue: 0.20), code: "SAU", logoAsset: "TeamLogos/kick-sauber"),
        "stake_f1_kick_sauber": .init(color: Color(red: 0.00, green: 0.91, blue: 0.20), code: "SAU", logoAsset: "TeamLogos/kick-sauber"),
        "rb":                   .init(color: Color(red: 0.40, green: 0.57, blue: 1.00), code: "RB",  logoAsset: "TeamLogos/racing-bulls"),
        "rb_f1_team":           .init(color: Color(red: 0.40, green: 0.57, blue: 1.00), code: "RB",  logoAsset: "TeamLogos/racing-bulls"),
        "alphatauri":           .init(color: Color(red: 0.40, green: 0.57, blue: 1.00), code: "AT",  logoAsset: "TeamLogos/racing-bulls"),
        "audi":                 .init(color: Color(red: 0.95, green: 0.05, blue: 0.20), code: "AUD", logoAsset: "TeamLogos/audi"),
        "cadillac":             .init(color: Color(red: 0.10, green: 0.30, blue: 0.55), code: "CAD", logoAsset: "TeamLogos/cadillac")
    ]
}

// MARK: - Team badge view (logo with text fallback)

struct TeamBadge: View {
    let constructorId: String
    var size: CGFloat = 32

    var body: some View {
        let b = ConstructorColors.brand(forConstructorId: constructorId)
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(b.color.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(b.color.opacity(0.55), lineWidth: 0.8)
                )
            if let asset = b.logoAsset {
                Image(asset)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(size * 0.12)
            } else {
                Text(b.code)
                    .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(b.color)
                            .padding(-size * 0.5)
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Country gradient

/// Provides a 2-color gradient inspired by a country's flag, used as a
/// subtle background tint on the next-race hero card.
enum CountryGradient {

    static func gradient(for country: String) -> LinearGradient {
        let colors = palette[country] ?? [Color(red: 0.20, green: 0.20, blue: 0.22),
                                          Color(red: 0.08, green: 0.08, blue: 0.10)]
        return LinearGradient(colors: colors,
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }

    private static let palette: [String: [Color]] = [
        "Australia":      [Color(red: 0.00, green: 0.13, blue: 0.40), Color(red: 0.78, green: 0.05, blue: 0.20)],
        "Austria":        [Color(red: 0.91, green: 0.00, blue: 0.13), Color.white.opacity(0.25)],
        "Azerbaijan":     [Color(red: 0.03, green: 0.59, blue: 0.85), Color(red: 0.91, green: 0.00, blue: 0.13)],
        "Bahrain":        [Color(red: 0.91, green: 0.00, blue: 0.13), Color.white.opacity(0.25)],
        "Belgium":        [Color.black, Color(red: 1.0, green: 0.86, blue: 0.0)],
        "Brazil":         [Color(red: 0.0, green: 0.62, blue: 0.38), Color(red: 1.0, green: 0.86, blue: 0.0)],
        "Canada":         [Color(red: 0.91, green: 0.00, blue: 0.13), Color.white.opacity(0.25)],
        "China":          [Color(red: 0.91, green: 0.00, blue: 0.13), Color(red: 1.0, green: 0.86, blue: 0.0)],
        "France":         [Color(red: 0.0, green: 0.21, blue: 0.62), Color(red: 0.93, green: 0.16, blue: 0.22)],
        "Germany":        [Color.black, Color(red: 0.93, green: 0.16, blue: 0.22)],
        "Hungary":        [Color(red: 0.81, green: 0.13, blue: 0.16), Color(red: 0.27, green: 0.55, blue: 0.27)],
        "Italy":          [Color(red: 0.00, green: 0.55, blue: 0.27), Color(red: 0.81, green: 0.13, blue: 0.16)],
        "Japan":          [Color(red: 0.74, green: 0.04, blue: 0.18), Color.white.opacity(0.25)],
        "Mexico":         [Color(red: 0.0, green: 0.41, blue: 0.27), Color(red: 0.81, green: 0.13, blue: 0.16)],
        "Monaco":         [Color(red: 0.81, green: 0.13, blue: 0.16), Color.white.opacity(0.25)],
        "Netherlands":    [Color(red: 0.68, green: 0.13, blue: 0.21), Color(red: 0.16, green: 0.20, blue: 0.50)],
        "Portugal":       [Color(red: 0.00, green: 0.40, blue: 0.20), Color(red: 0.81, green: 0.13, blue: 0.16)],
        "Qatar":          [Color(red: 0.45, green: 0.10, blue: 0.30), Color.white.opacity(0.25)],
        "Saudi Arabia":   [Color(red: 0.0, green: 0.42, blue: 0.22), Color.white.opacity(0.25)],
        "Singapore":      [Color(red: 0.93, green: 0.16, blue: 0.22), Color.white.opacity(0.25)],
        "Spain":          [Color(red: 0.81, green: 0.13, blue: 0.16), Color(red: 1.0, green: 0.78, blue: 0.0)],
        "UAE":            [Color(red: 0.0, green: 0.45, blue: 0.34), Color(red: 0.93, green: 0.16, blue: 0.22)],
        "United Arab Emirates": [Color(red: 0.0, green: 0.45, blue: 0.34), Color(red: 0.93, green: 0.16, blue: 0.22)],
        "UK":             [Color(red: 0.0, green: 0.14, blue: 0.40), Color(red: 0.81, green: 0.13, blue: 0.16)],
        "United Kingdom": [Color(red: 0.0, green: 0.14, blue: 0.40), Color(red: 0.81, green: 0.13, blue: 0.16)],
        "United States":  [Color(red: 0.0, green: 0.20, blue: 0.40), Color(red: 0.81, green: 0.13, blue: 0.16)],
        "USA":            [Color(red: 0.0, green: 0.20, blue: 0.40), Color(red: 0.81, green: 0.13, blue: 0.16)]
    ]
}
