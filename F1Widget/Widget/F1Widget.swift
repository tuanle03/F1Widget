//
//  F1Widget.swift
//  F1WidgetExtension
//
//  Defines the Widget + WidgetBundle (entry point of the widget extension).
//

import WidgetKit
import SwiftUI

struct F1WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: F1Entry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [F1Theme.card, Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .foregroundStyle(.white)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        case .systemLarge:  LargeWidgetView(entry: entry)
        default:            MediumWidgetView(entry: entry)
        }
    }
}

struct F1Widget: Widget {
    let kind = "F1Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: F1Provider()) { entry in
            F1WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("F1 Schedule")
        .description("Next race, session schedule in your local time, and driver standings.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct F1WidgetBundle: WidgetBundle {
    var body: some Widget {
        F1Widget()
    }
}
