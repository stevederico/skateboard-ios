//
//  SKAppDelegate.swift
//

import UIKit
import UserNotifications

/// UserDefaults key for the latest APNs device token (hex).
public let SKPushTokenKey = "SKPushToken"

public extension Notification.Name {
    /// Posted with the hex APNs token as `object` when the device registers.
    static let skPushToken = Notification.Name("SKPushToken")
    /// Posted with a path or URL as `object` when a push or link should open a page.
    static let skOpenURL = Notification.Name("SKOpenURL")
}

/// Base application delegate for hybrid web-native applications.
///
/// `SKAppDelegate` provides the foundation for managing the application lifecycle
/// in a hybrid app. It configures the scene session and delegates window management
/// to ``SKSceneDelegate``.
///
/// ## Subclassing
///
/// For most applications, subclass this delegate and mark it with `@main`:
///
/// ```swift
/// @main
/// class AppDelegate: SKAppDelegate {
///     // App-specific customization
/// }
/// ```
///
/// - SeeAlso: ``SKSceneDelegate`` for scene lifecycle management
/// - SeeAlso: ``SKAppController`` for the view controller implementation
/// - SeeAlso: ``AppController`` for app-specific controller customization
///
/// It also handles push notifications: the APNs token goes to the web app as a
/// `PushRegistered` event, and a push payload's `url` key (a path like
/// `/app/list`, or a full URL on the app's host) opens that page on tap.
open class SKAppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Called when the application finishes launching.
    ///
    /// - Parameters:
    ///   - application: The singleton app object.
    ///   - launchOptions: A dictionary indicating the reason the app was launched.
    /// - Returns: `true` to indicate successful launch.
    open func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Re-register quietly when permission was already granted, so a fresh
        // token reaches the server after a reinstall or restore.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async { application.registerForRemoteNotifications() }
            }
        }
        return true
    }

    // MARK: - UISceneSession Lifecycle

    /// Returns the configuration for creating a new scene session.
    ///
    /// Called when a new scene session is being created. Returns the configuration
    /// that specifies ``SKSceneDelegate`` as the scene delegate class.
    ///
    /// - Parameters:
    ///   - application: The singleton app object.
    ///   - connectingSceneSession: The session object for the new scene.
    ///   - options: Options for configuring the scene.
    /// - Returns: The configuration object for the new scene.
    open func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    /// Called when the user discards a scene session.
    ///
    /// - Parameters:
    ///   - application: The singleton app object.
    ///   - sceneSessions: The sessions that were discarded.
    open func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    // MARK: - Push notifications

    /// Saves the hex token and hands it to the controller, which sends it to the web app.
    open func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: SKPushTokenKey)
        NotificationCenter.default.post(name: .skPushToken, object: token)
    }

    open func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Push registration failed: \(error.localizedDescription)")
    }

    /// Shows notifications that arrive while the app is open.
    open func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// A tap opens the page named by the payload's `url`, if any.
    open func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let url = response.notification.request.content.userInfo["url"] as? String {
            // Give the scene a moment to attach the controller after a cold start.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .skOpenURL, object: url)
            }
        }
        completionHandler()
    }
}
