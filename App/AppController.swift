//
//  AppController.swift
//

import UIKit

/// App-specific view controller subclass for customization.
///
/// `AppController` serves as the customization point for the hybrid application.
/// Override methods from ``SKAppController`` to add app-specific behavior such as:
/// - Custom JavaScript message handlers
/// - Additional native UI elements
/// - Modified navigation behavior
/// - Analytics or logging integration
///
/// ## Example
///
/// ```swift
/// public class AppController: SKAppController {
///     public override func viewDidLoad() {
///         super.viewDidLoad()
///         // Add custom UI elements
///         // Configure analytics
///     }
///
///     public override func appEvent(eventString: String) {
///         super.appEvent(eventString: eventString)
///         // Log events to analytics service
///     }
/// }
/// ```
///
/// - SeeAlso: ``SKAppController`` for the base implementation
public class AppController: SKAppController {

    /// Called after the controller's view is loaded into memory.
    ///
    /// Override this method to perform additional setup after the web view
    /// is configured. Always call `super.viewDidLoad()` first.
    public override func viewDidLoad() {
        super.viewDidLoad()

        // Custom setup here
    }
}
