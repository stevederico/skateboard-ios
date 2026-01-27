//
//  SKAppDelegate.swift
//

import UIKit

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
open class SKAppDelegate: UIResponder, UIApplicationDelegate {

    /// Called when the application finishes launching.
    ///
    /// - Parameters:
    ///   - application: The singleton app object.
    ///   - launchOptions: A dictionary indicating the reason the app was launched.
    /// - Returns: `true` to indicate successful launch.
    open func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
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
}
