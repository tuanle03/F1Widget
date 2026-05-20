//
//  UpdaterController.swift
//  F1Widget
//
//  Wraps Sparkle's SPUStandardUpdaterController so the host app can check
//  for updates from a GitHub Pages-hosted appcast.xml, verify them with an
//  EdDSA signature, download, and install in-place.
//

import Foundation
import SwiftUI
import Sparkle

@MainActor
@Observable
final class UpdaterController {
    static let shared = UpdaterController()

    let controller: SPUStandardUpdaterController

    var canCheckForUpdates: Bool = false
    var lastCheckDate: Date?

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        canCheckForUpdates = controller.updater.canCheckForUpdates
        lastCheckDate = controller.updater.lastUpdateCheckDate
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
        lastCheckDate = Date()
    }

    /// Whether the app silently checks for updates on a schedule.
    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    /// How often Sparkle polls the appcast.xml (in seconds).
    var checkInterval: TimeInterval {
        get { controller.updater.updateCheckInterval }
        set { controller.updater.updateCheckInterval = newValue }
    }
}

// MARK: - Settings row helper

struct UpdaterSettingsBlock: View {
    @State private var updater = UpdaterController.shared
    @AppStorage("automaticUpdateChecks") private var automaticUpdateChecks = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Automatically check for updates", isOn: $automaticUpdateChecks)
                .onChange(of: automaticUpdateChecks) { _, newValue in
                    updater.automaticallyChecks = newValue
                }
                .onAppear {
                    updater.automaticallyChecks = automaticUpdateChecks
                }

            HStack {
                Button("Check for updates now") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
                Spacer()
                if let date = updater.lastCheckDate {
                    Text("Last checked \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Update releases are EdDSA-signed and downloaded directly from the project's GitHub Releases page.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
