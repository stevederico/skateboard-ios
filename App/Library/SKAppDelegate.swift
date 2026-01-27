//
//  SKAppDelegate.swift
//

import UIKit

/// Base application delegate for hybrid web-native applications.
///
/// `SKAppDelegate` provides the foundation for managing the application lifecycle
/// in a hybrid app. It creates the main window, sets up the ``AppController`` as
/// the root view controller, and handles foreground transitions by reloading
/// the base URL.
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
/// - SeeAlso: ``SKAppController`` for the view controller implementation
/// - SeeAlso: ``AppController`` for app-specific controller customization
open class SKAppDelegate: UIResponder, UIApplicationDelegate {

    /// The main application window.
    ///
    /// Created and configured during ``application(_:didFinishLaunchingWithOptions:)``.
    public var window: UIWindow?

    /// The root view controller managing the hybrid web view.
    ///
    /// Instantiated with the default ``AppController`` implementation.
    /// Override in subclasses to provide a custom controller.
    public var appController = AppController()

    /// Configures the application window and sets up the root view controller.
    ///
    /// Called when the application finishes launching. Creates a full-screen window
    /// and presents the ``appController`` as the root view controller.
    ///
    /// - Parameters:
    ///   - application: The singleton app object.
    ///   - launchOptions: A dictionary indicating the reason the app was launched.
    /// - Returns: `true` to indicate successful launch.
    open func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        window!.rootViewController = appController
        window!.makeKeyAndVisible()
        return true
    }

    /// Reloads the base URL when the application returns to the foreground.
    ///
    /// Called when the app transitions from background to active state.
    /// Ensures the web content is refreshed with the latest data.
    ///
    /// - Parameter application: The singleton app object.
    open func applicationWillEnterForeground(_ application: UIApplication) {
        self.appController.loadURL(urlString: AppConstants.APP_URL)
    }
}
