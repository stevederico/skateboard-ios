//
//  SceneDelegate.swift
//

import UIKit

/// The scene delegate for the iOS application.
///
/// Manages the scene lifecycle, creates the window, and sets up the
/// ``AppController`` as the root view controller.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    /// The scene's window.
    var window: UIWindow?

    /// The root view controller managing the hybrid web view.
    var appController = AppController()

    /// Configures the scene window and sets up the root view controller.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        // Match the system background so there's no white flash before the page paints.
        window?.backgroundColor = .systemBackground
        window?.rootViewController = appController
        window?.makeKeyAndVisible()

        // Launched from a universal link: open that page.
        if let activity = connectionOptions.userActivities.first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb }),
           let url = activity.webpageURL {
            appController.open(path: url.absoluteString)
        }
    }

    /// Opens a universal link tapped while the app is running.
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else { return }
        appController.open(path: url.absoluteString)
    }

    /// Keeps people where they were when they come back; starts over only
    /// after 30 minutes away.
    func sceneWillEnterForeground(_ scene: UIScene) {
        appController.refreshIfStale(after: 30 * 60)
    }
}
