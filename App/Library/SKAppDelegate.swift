//
//  SKAppDelegate.swift
//

import UIKit

open class SKAppDelegate: UIResponder, UIApplicationDelegate {

    public var window: UIWindow?
    public var appController = AppController()

    open func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        window!.rootViewController = appController
        window!.makeKeyAndVisible()
        return true
    }

    open func applicationWillEnterForeground(_ application: UIApplication) {
        self.appController.loadURL(urlString: AppConstants.BASE_URL)
    }
}
