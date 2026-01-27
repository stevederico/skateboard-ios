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
        window?.rootViewController = appController
        window?.makeKeyAndVisible()
    }

    /// Reloads the base URL when the scene enters the foreground.
    func sceneWillEnterForeground(_ scene: UIScene) {
        appController.loadURL(urlString: AppConstants.APP_URL)
    }
}
