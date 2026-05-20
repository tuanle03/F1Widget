//
//  MenuBarContent.swift
//  F1Widget
//
//  Menu bar label (small icon + live countdown) and popover content (mini
//  dashboard summary) for the always-visible menu bar presence.
//

import SwiftUI

// MARK: - Label shown next to the menu bar icon
//
// NOTE: MenuBarExtra rebuilds the label slot on every observed change, and
// putting a live-updating view here (TimelineView, etc.) triggers a tight
// rebuild loop in AppKit. Keep this view STATIC. The live countdown lives in
// the popover content where it's safe.

struct MenuBarLabel: View {
    var body: some View {
        Image(systemName: "flag.checkered")
    }
}

// MARK: - Popover content

struct MenuBarContent: View {
    var model: DashboardModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let weekend = upcomingWeekend {
                weekendBlock(weekend)
            } else if model.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("No upcoming F1 weekend.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Refresh") { Task { await model.loadAll() } }
                    .buttonStyle(.borderless)
                    .disabled(model.isLoading)
                Spacer()
                Button("Open App") { openMainWindow() }
                    .buttonStyle(.borderless)
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 320)
        .task { if model.weekends.isEmpty { await model.loadAll() } }
    }

    private var upcomingWeekend: RaceWeekend? {
        F1Snapshot(weekends: model.weekends, standings: model.driverStandings)
            .upcomingWeekend()
    }

    @ViewBuilder
    private func weekendBlock(_ weekend: RaceWeekend) -> some View {
        let next = weekend.nextSession(after: Date())
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(weekend.countryFlag).font(.title3)
                VStack(alignment: .leading, spacing: 0) {
                    Text(weekend.name).font(.subheadline.bold()).lineLimit(1)
                    Text("\(weekend.locality) · Round \(weekend.round)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let next {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("NEXT")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(next.kind.rawValue).font(.callout.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(next.start, style: .relative)
                            .font(.callout.bold().monospacedDigit())
                            .foregroundStyle(.red)
                        Text(next.start.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            Divider().padding(.vertical, 4)
            ForEach(weekend.sessions.suffix(5)) { s in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(s.id == next?.id ? Color.red : Color.clear)
                        .frame(width: 2, height: 12)
                    Text(s.kind.rawValue).font(.caption).frame(width: 90, alignment: .leading)
                    Spacer()
                    Text(s.start.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(s.start.formatted(date: .omitted, time: .shortened))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(s.id == next?.id ? .red : .primary)
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
    }

    private func openMainWindow() {
        // Promote back to Dock-visible mode so the window has an app context.
        if let delegate = NSApp.delegate as? AppDelegate {
            NSApp.setActivationPolicy(.regular)
            _ = delegate
        }
        NSApp.activate(ignoringOtherApps: true)
        // Recreate or focus the main window.
        openWindow(id: "main")
    }
}
