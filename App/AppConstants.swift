//
//  AppConstants.swift
//

import Foundation

/// Configuration constants for the hybrid application.
///
/// `AppConstants` centralizes all app-specific configuration values including
/// App Store identifiers, product IDs, and web content URLs. Modify these values
/// to configure the application for your specific use case.
///
/// ## Usage
///
/// Reference constants directly via the struct:
/// ```swift
/// let url = AppConstants.APP_URL
/// ```
struct AppConstants {
    /// The App Store application identifier.
    ///
    /// Used for generating App Store links in share sheets and review prompts.
    /// Replace with your app's actual App Store ID from App Store Connect.
    ///
    /// - Note: Format is a 9-10 digit numeric string (e.g., `"1234567890"`).
    static let APP_STORE_ID = "000000000"

    /// The StoreKit product identifier for the subscription offering.
    ///
    /// Must match a product ID configured in App Store Connect.
    /// Used by ``SKAppController/loadSubscriptionOptions()`` to fetch product details.
    ///
    /// - Note: Uses reverse-domain notation (e.g., `"com.company.app.subscription"`).
    static let SUBSCRIPTION_URL = "com.yourcompany.app.subscription"

    /// The base URL for the hybrid web application content.
    ///
    /// Loaded on app launch and when returning from background.
    /// Should point to the entry point of your web application.
    static let APP_URL = "https://your-webapp.com"
}
