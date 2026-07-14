import Observation
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

@main
@MainActor
struct HumanCollectiveApp: App {
    @UIApplicationDelegateAdaptor(HumanCultureAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var supportStore = SupportStore()
    @State private var savedStore = SavedStore()
    @State private var blockedCommunityStore = BlockedCommunityStore()
    private let repository: any CultureRepository = CultureRepositoryFactory.make()
    private let communityRepository: any CommunityRepository = CommunityRepositoryFactory.make()

    init() {
        AppChrome.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                repository: repository,
                communityRepository: communityRepository,
                savedStore: savedStore,
                blockedCommunityStore: blockedCommunityStore,
                supportStore: supportStore
            )
                .preferredColorScheme(.light)
                .task {
                    supportStore.start()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }
}

final class HumanCultureAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard notification.request.identifier == DailyNotificationManager.reminderIdentifier else { return [] }
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier == DailyNotificationManager.reminderIdentifier else { return }

        await MainActor.run {
            NotificationCenter.default.post(name: .humanCultureOpenToday, object: nil)
        }
    }
}

@MainActor
@Observable
final class DailyNotificationManager {
    enum AuthorizationState: Equatable {
        case checking
        case notDetermined
        case enabled
        case denied
    }

    nonisolated static let reminderIdentifier = "humanCulture.dailyPieceReminder"

    var authorizationState: AuthorizationState = .checking

    var reminderTimeText: String {
        "Daily at 9 AM"
    }

    @ObservationIgnored private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationState = Self.state(for: settings.authorizationStatus)

        if authorizationState == .enabled {
            try? await scheduleDailyReminder()
        }
    }

    func prepareDailyReminder() async {
        let settings = await center.notificationSettings()
        authorizationState = Self.state(for: settings.authorizationStatus)

        switch authorizationState {
        case .enabled:
            try? await scheduleDailyReminder()
        case .notDetermined:
            await enableDailyReminder()
        case .checking, .denied:
            break
        }
    }

    func enableDailyReminder() async {
        authorizationState = .checking

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else {
                authorizationState = .denied
                return
            }

            try await scheduleDailyReminder()
            authorizationState = .enabled
        } catch {
            authorizationState = .denied
        }
    }

    private func scheduleDailyReminder() async throws {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "New daily piece"
        content.body = "You have a new piece to look at."
        content.sound = .default
        content.userInfo = ["destination": "today"]

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.reminderIdentifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    private static func state(for status: UNAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .enabled
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }
}

extension Notification.Name {
    static let humanCultureOpenToday = Notification.Name("humanCultureOpenToday")
}

private enum AppChrome {
    static func configure() {
        let background = UIColor(red: 0.963, green: 0.948, blue: 0.918, alpha: 1)

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = background
        navigationAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
    }
}
