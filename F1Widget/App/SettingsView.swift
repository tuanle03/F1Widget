//
//  SettingsView.swift
//  F1Widget
//
//  In-app settings panel: toggles for menu bar presence + session notifications.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    var model: DashboardModel

    @AppStorage(AppSettingsKey.showInMenuBar)          private var showInMenuBar = true
    @AppStorage(AppSettingsKey.showCountdownInMenuBar) private var showCountdownInMenuBar = true
    @AppStorage(AppSettingsKey.notificationsEnabled)   private var notificationsEnabled = false
    @AppStorage(AppSettingsKey.notificationLeadMinutes) private var notificationLeadMinutes: Int = 15
    @AppStorage(AppSettingsKey.notifySessionFilter)    private var notifySessionFilterRaw: String = SessionFilter.qualifyingAndRace.rawValue

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private let leadOptions = [5, 10, 15, 30, 60]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                menuBarSection
                notificationSection
                aboutSection
            }
            .padding(20)
        }
        .task { notificationStatus = await NotificationScheduler.authorizationStatus() }
    }

    // MARK: Menu Bar section

    private var menuBarSection: some View {
        CardSection(title: "MENU BAR") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show F1 icon in menu bar", isOn: $showInMenuBar)
                Toggle("Show countdown next to icon", isOn: $showCountdownInMenuBar)
                    .disabled(!showInMenuBar)
                Text("The menu bar icon shows a live countdown to the next F1 session and reveals a mini dashboard on click.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtle)
            }
        }
    }

    // MARK: Notification section

    private var notificationSection: some View {
        CardSection(title: "NOTIFICATIONS") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Notify before each session", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        Task { await handleNotificationToggle(newValue) }
                    }

                if notificationStatus == .denied {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Notifications are blocked. Enable them in System Settings → Notifications → F1Widget.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtle)
                    }
                }

                Picker("Notify me", selection: Binding(
                    get: { SessionFilter(rawValue: notifySessionFilterRaw) ?? .qualifyingAndRace },
                    set: { notifySessionFilterRaw = $0.rawValue; rescheduleIfEnabled() }
                )) {
                    ForEach(SessionFilter.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!notificationsEnabled)

                HStack {
                    Text("Lead time")
                    Spacer()
                    Picker("", selection: $notificationLeadMinutes) {
                        ForEach(leadOptions, id: \.self) { mins in
                            Text("\(mins) min").tag(mins)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 100)
                    .onChange(of: notificationLeadMinutes) { _, _ in rescheduleIfEnabled() }
                }
                .disabled(!notificationsEnabled)

                Text("Local banners that appear in Notification Center and on the lock screen, shortly before each session begins.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtle)
            }
        }
    }

    // MARK: About

    private var aboutSection: some View {
        CardSection(title: "ABOUT") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion).foregroundStyle(AppTheme.subtle)
                }
                Text("F1 schedule data: jolpica-f1. Circuit outlines: bacinger/f1-circuits (MIT). Team logos: formula1.com + Wikimedia Commons. Times are shown in your local time zone.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtle)
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    // MARK: Actions

    private func handleNotificationToggle(_ enabled: Bool) async {
        if enabled {
            let status = await NotificationScheduler.authorizationStatus()
            if status == .notDetermined {
                let granted = await NotificationScheduler.requestAuthorization()
                if !granted {
                    notificationsEnabled = false
                }
            } else if status == .denied {
                notificationsEnabled = false
            }
            notificationStatus = await NotificationScheduler.authorizationStatus()
        }
        rescheduleIfEnabled()
    }

    private func rescheduleIfEnabled() {
        let weekends = model.weekends
        let enabled = notificationsEnabled
        let lead = notificationLeadMinutes
        let filter = SessionFilter(rawValue: notifySessionFilterRaw) ?? .qualifyingAndRace
        Task {
            if enabled {
                await NotificationScheduler.reschedule(weekends: weekends,
                                                       leadMinutes: lead,
                                                       filter: filter)
            } else {
                NotificationScheduler.cancelAll()
            }
        }
    }
}
