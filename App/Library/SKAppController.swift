//
//  SKAppController.swift
//

import UIKit
@preconcurrency import WebKit
import StoreKit
import UserNotifications
import Network
import AVFoundation

/// A hybrid web-native view controller that bridges WebKit and StoreKit functionality.
///
/// `SKAppController` provides a foundation for building hybrid iOS applications that combine
/// web content with native iOS features. It manages a full-screen `WKWebView` and exposes
/// a JavaScript bridge via `WKScriptMessageHandler` to enable bidirectional communication
/// between web content and native code.
///
/// ## Architecture
///
/// The controller follows a hybrid web-native pattern:
/// - Web content is loaded in a `WKWebView` and drives the UI
/// - Native capabilities (StoreKit, sharing, etc.) are exposed via message handlers
/// - Events are dispatched back to JavaScript via custom DOM events on `#skhub`
///
/// ## JavaScript Bridge
///
/// Web content can invoke native functionality by posting messages to `SKMessageHandler`:
/// ```javascript
/// webkit.messageHandlers.SKMessageHandler.postMessage({
///     action: 'purchasetapped',
///     uuid: 'user-uuid-string'
/// });
/// ```
///
/// Supported actions:
/// - `showshare`: Present the system share sheet
/// - `showrate`: Open App Store review page
/// - `restorepurchases`: Restore previous purchases
/// - `purchasetapped`: Initiate a purchase flow
/// - `showactivity` / `hideactivity`: Control loading indicator
/// - `getpid`: Load a specific product ID
/// - `userready`: Request language and version info
///
/// - SeeAlso: ``AppController`` for app-specific customization
/// - SeeAlso: ``SKAppDelegate`` for application lifecycle management
open class SKAppController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate, UIScrollViewDelegate {

    /// The available StoreKit products fetched from App Store Connect.
    ///
    /// Populated asynchronously after calling ``loadSubscriptionOptions()``.
    /// Empty until products are successfully loaded.
    open var products = [Product]()

    /// The unique user identifier used for App Account Token during purchases.
    ///
    /// This UUID links purchases to a specific user account in your backend.
    /// Set via the `uuid` parameter in the `purchasetapped` message action.
    open var uuidString = ""

    /// The most recently loaded URL in the web view.
    ///
    /// Updated each time ``loadURL(urlString:)`` is called. Useful for tracking
    /// navigation state or reloading the current page.
    open var lastURL = ""

    /// The product identifier for the subscription being offered.
    ///
    /// Defaults to ``AppConstants/SUBSCRIPTION_URL``. Can be dynamically updated
    /// via the `getpid` message action from JavaScript.
    open var productID = AppConstants.SUBSCRIPTION_URL

    /// Background task listening for StoreKit transaction updates.
    var updates: Task<Void, Never>? = nil

    /// When the current page was last loaded, for ``refreshIfStale(after:)``.
    open var lastLoadDate: Date? = nil

    /// The web view displaying the hybrid application content.
    ///
    /// Configured with inline media playback enabled and a message handler
    /// registered for `SKMessageHandler`. Back/forward navigation gestures
    /// are disabled.
    open var webView = WKWebView()

    /// The overlay view containing the activity indicator.
    var activityView = UIView()

    /// Tracks whether the activity indicator is currently visible.
    var isActivityShowing = false

    /// Creates a new app controller with a configured web view and StoreKit listener.
    ///
    /// Initializes the web view with inline media playback support, registers the
    /// JavaScript message handler, and starts listening for StoreKit transaction updates.
    /// If a product ID is configured, subscription options are loaded asynchronously.
    public required init() {
        super.init(nibName: nil, bundle: nil)

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(self, name: "SKMessageHandler")

        webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        webView.uiDelegate = self
        // Transparent until the page paints, so the system background (dark in
        // dark mode) shows instead of a white flash at launch.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        NotificationCenter.default.addObserver(self, selector: #selector(pushTokenReceived(_:)), name: .skPushToken, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openURLRequested(_:)), name: .skOpenURL, object: nil)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        webView.pageZoom = CGFloat(floatLiteral: 1.0)

        updates = updatesListenerTask()

        if self.productID.count > 0 {
            Task {
                await self.loadSubscriptionOptions()
            }
        }
    }

    deinit {
        updates?.cancel()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .systemBackground

        self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        self.webView.navigationDelegate = self
        self.webView.scrollView.showsVerticalScrollIndicator = false
        self.webView.scrollView.showsHorizontalScrollIndicator = false
        self.webView.scrollView.delegate = self
        self.webView.scrollView.pinchGestureRecognizer?.isEnabled = false

        self.view.addSubview(self.webView)
        self.webView.isHidden = false
        self.webView.translatesAutoresizingMaskIntoConstraints = false
        self.webView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 0).isActive = true
        self.webView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: 0).isActive = true
        self.webView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
        self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true

        self.loadURL(urlString: AppConstants.APP_URL)

        activityView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        activityView.backgroundColor = .clear

        let activitySquare = UIView()
        activitySquare.backgroundColor = .black
        activitySquare.layer.opacity = 0.70
        activitySquare.layer.cornerRadius = 12.0
        activityView.addSubview(activitySquare)
        activitySquare.translatesAutoresizingMaskIntoConstraints = false
        activitySquare.centerXAnchor.constraint(equalTo: activityView.centerXAnchor, constant: 0).isActive = true
        activitySquare.centerYAnchor.constraint(equalTo: activityView.centerYAnchor, constant: 0).isActive = true
        activitySquare.heightAnchor.constraint(equalToConstant: CGFloat(100)).isActive = true
        activitySquare.widthAnchor.constraint(equalToConstant: CGFloat(100)).isActive = true

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.startAnimating()
        activityView.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.centerXAnchor.constraint(equalTo: activityView.centerXAnchor, constant: 0).isActive = true
        activityIndicator.centerYAnchor.constraint(equalTo: activityView.centerYAnchor, constant: 0).isActive = true
        activityIndicator.heightAnchor.constraint(equalToConstant: CGFloat(100)).isActive = true
        activityIndicator.widthAnchor.constraint(equalToConstant: CGFloat(100)).isActive = true
    }

    override open var preferredStatusBarStyle: UIStatusBarStyle {
        // Follow the system appearance: light text in dark mode.
        return .default
    }

    open override var prefersStatusBarHidden: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Displays a centered loading indicator overlay on the web view.
    ///
    /// The activity indicator appears as a semi-transparent black rounded square
    /// with a spinning indicator. Automatically hides after 15 seconds as a safety timeout.
    /// Dispatches an `ActivityShown` event to JavaScript.
    ///
    /// - Note: Calling this method when the indicator is already showing has no effect.
    /// - SeeAlso: ``hideActivity()``
    public func showActivity() {
        if isActivityShowing {
            return
        }

        isActivityShowing = true

        DispatchQueue.main.async {
            self.webView.addSubview(self.activityView)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            self.hideActivity()
        }
        self.appEvent(eventString: "ActivityShown")
    }

    /// Removes the loading indicator overlay from the web view.
    ///
    /// Dispatches an `ActivityHidden` event to JavaScript.
    ///
    /// - SeeAlso: ``showActivity()``
    public func hideActivity() {
        DispatchQueue.main.async {
            self.activityView.removeFromSuperview()
        }

        isActivityShowing = false
        self.appEvent(eventString: "ActivityHidden")
    }

    // MARK: - WKWebView

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            self.webView.load(navigationAction.request)
        }
        return nil
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           !url.absoluteString.hasPrefix("http://"),
           !url.absoluteString.hasPrefix("https://"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    public func viewForZooming(in: UIScrollView) -> UIView? {
        return nil
    }

    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }

    /// Loads web content from the specified URL.
    ///
    /// The request includes a custom `SK-Browser` header for server-side detection
    /// and disables caching to ensure fresh content.
    ///
    /// - Parameter urlString: The URL string to load. Must be a valid URL.
    /// - Note: Updates ``lastURL`` before loading.
    @objc open func loadURL(urlString: String) {
        self.lastURL = urlString
        self.lastLoadDate = Date()

        DispatchQueue.main.async {
            let url = URL(string: urlString)!
            var request = URLRequest(url: url)
            request.setValue("SK-Browser", forHTTPHeaderField: "SK-Browser")
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            self.webView.load(request)
        }
    }

    /// Reload the start page only when it was loaded more than `seconds` ago,
    /// so switching apps keeps the person where they were.
    open func refreshIfStale(after seconds: TimeInterval) {
        guard let last = lastLoadDate else {
            loadURL(urlString: AppConstants.APP_URL)
            return
        }
        if Date().timeIntervalSince(last) > seconds {
            loadURL(urlString: AppConstants.APP_URL)
        }
    }

    /// Open a path ("/app/list") or a full URL on the app's own host in the
    /// web view. Anything else is ignored.
    open func open(path: String) {
        guard let base = URL(string: AppConstants.APP_URL), let host = base.host else { return }
        if path.hasPrefix("/") {
            var parts = URLComponents()
            parts.scheme = base.scheme
            parts.host = host
            parts.port = base.port
            let pieces = path.split(separator: "?", maxSplits: 1).map(String.init)
            parts.path = pieces[0]
            parts.percentEncodedQuery = pieces.count > 1 ? pieces[1] : nil
            if let url = parts.url { loadURL(urlString: url.absoluteString) }
        } else if let url = URL(string: path), url.host == host, url.scheme == "https" {
            loadURL(urlString: url.absoluteString)
        }
    }

    // MARK: - Push notifications

    /// Ask for notification permission, then register with APNs. The web app
    /// sends `askpush` at a good moment (not at launch).
    open func requestPush() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            self.appEventWithDetails(eventString: "PushPermission", jsonDetails: "'granted':'\(granted ? "yes" : "no")'")
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Hand the APNs token (hex) to the web app as a `PushRegistered` event.
    open func sendPushToken(_ token: String) {
        appEventWithDetails(eventString: "PushRegistered", jsonDetails: "'token':'\(token)'")
    }

    @objc func pushTokenReceived(_ note: Notification) {
        if let token = note.object as? String { sendPushToken(token) }
    }

    @objc func openURLRequested(_ note: Notification) {
        if let path = note.object as? String { open(path: path) }
    }

    /// Once a page finishes loading, resend a saved push token so the web app
    /// can store it for whoever is signed in.
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let token = UserDefaults.standard.string(forKey: SKPushTokenKey) {
            sendPushToken(token)
        }
    }

    // MARK: - JS Message Handler

    /// Handles incoming messages from JavaScript via the `SKMessageHandler` bridge.
    ///
    /// The message body should be a dictionary with an `action` key specifying the
    /// operation to perform. Additional parameters depend on the action type.
    ///
    /// ## Supported Actions
    ///
    /// | Action | Parameters | Description |
    /// |--------|------------|-------------|
    /// | `showshare` | `appid` | Present share sheet with App Store link |
    /// | `showrate` | `appid` | Open App Store review page |
    /// | `restorepurchases` | — | Restore previous purchases via StoreKit |
    /// | `purchasetapped` | `uuid` | Initiate purchase with user account token |
    /// | `showactivity` | — | Show loading indicator |
    /// | `hideactivity` | — | Hide loading indicator |
    /// | `getpid` | `subscriptionURL` | Load a specific product ID |
    /// | `userready` | — | Request language and version info |
    ///
    /// - Parameters:
    ///   - userContentController: The content controller that received the message.
    ///   - message: The script message containing the action dictionary.
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        var action = "none"
        let dic = message.body as? [String: String]
        if let actionUnwrapped = dic?["action"] {
            if action.count > 0 {
                action = actionUnwrapped
            }
        }

        if action.lowercased() == "askpush" {
            requestPush()
            return
        }

        if action.lowercased() == "openpath", let path = dic?["path"] {
            open(path: path)
            return
        }

        if action.lowercased() == "showshare" {
            var appStoreID = ""
            if let aUnwrapped = dic?["appid"] {
                if aUnwrapped.count > 0 {
                    appStoreID = aUnwrapped
                }
            }

            let text = "check out this new app"
            let myWebsite = NSURL(string: "https://itunes.apple.com/app/id\(appStoreID)?mt=8")
            let shareAll = [text, UIImage(), myWebsite!] as [Any]
            let activityViewController = UIActivityViewController(activityItems: shareAll, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true, completion: nil)
            return

        } else if action.lowercased() == "showrate" {
            var appStoreID = ""
            if let aUnwrapped = dic?["appid"] {
                if aUnwrapped.count > 0 {
                    appStoreID = aUnwrapped
                }
            }

            Task {
                await UIApplication.shared.open(NSURL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review")! as URL)
            }
            return

        } else if action.lowercased() == "restorepurchases" {
            showActivity()
            Task {
                let result = await restore()
                hideActivity()
                if result == true {
                    DispatchQueue.main.async {
                        let alertController = UIAlertController(title: "Purchases Restored", message: "", preferredStyle: .alert)
                        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alertController.addAction(defaultAction)
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
            return

        } else if action.lowercased() == "userready" {
            getLangVersion()
            return

        } else if action.lowercased() == "showactivity" {
            showActivity()
            return

        } else if action.lowercased() == "hideactivity" {
            hideActivity()
            return

        } else if action.lowercased() == "getpid" {
            if let subURLUnwrapped = dic?["subscriptionURL"] {
                if subURLUnwrapped.count > 0 {
                    self.productID = subURLUnwrapped
                    Task {
                        await self.loadSubscriptionOptions()
                    }
                }
            }
            return

        } else if action.lowercased() == "purchasetapped" {
            if let aUnwrapped = dic?["uuid"] {
                if aUnwrapped.count > 0 {
                    self.uuidString = aUnwrapped
                }
            }

            self.purchaseTapped()
            return
        }

        return
    }

    /// Dispatches a custom event to the JavaScript layer.
    ///
    /// Fires an `app-event` CustomEvent on the `#skhub` element with the specified
    /// event title. The web application can listen for these events to react to
    /// native state changes.
    ///
    /// ```javascript
    /// document.querySelector('#skhub').addEventListener('app-event', (e) => {
    ///     console.log(e.detail.title); // e.g., "PurchaseComplete"
    /// });
    /// ```
    ///
    /// - Parameter eventString: The event title to include in the detail payload.
    /// - SeeAlso: ``appEventWithDetails(eventString:jsonDetails:)``
    public func appEvent(eventString: String) {
        DispatchQueue.main.async {
            let script = "document.querySelector('#skhub').dispatchEvent( new CustomEvent('app-event', {'detail':  {'title': '\(eventString)'}}));"
            self.webView.evaluateJavaScript(script)
        }
    }

    /// Dispatches a custom event with additional JSON payload to the JavaScript layer.
    ///
    /// Similar to ``appEvent(eventString:)`` but includes additional key-value pairs
    /// in the event detail object.
    ///
    /// - Parameters:
    ///   - eventString: The event title to include in the detail payload.
    ///   - jsonDetails: Additional JSON key-value pairs to merge into the detail object.
    ///                  Should be formatted as `'key':'value'` without outer braces.
    public func appEventWithDetails(eventString: String, jsonDetails: String) {
        DispatchQueue.main.async {
            let script = "document.querySelector('#skhub').dispatchEvent( new CustomEvent('app-event', {'detail':  {'title': '\(eventString)', \(jsonDetails)}}));"
            self.webView.evaluateJavaScript(script)
        }
    }

    /// Returns the current device locale identifier.
    ///
    /// - Returns: The locale identifier string (e.g., `"en_US"`, `"fr_FR"`).
    open func getLang() -> String {
        let locale = NSLocale.current.identifier
        return locale
    }

    /// Returns the app's short version string from the bundle.
    ///
    /// - Returns: The `CFBundleShortVersionString` value (e.g., `"1.0.0"`), or `"0.0"` if unavailable.
    open func getVersion() -> String {
        var versionString = "0.0"
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            versionString = version
        }
        return versionString
    }

    /// Dispatches both version and language information to JavaScript.
    ///
    /// Fires two separate `app-event` events:
    /// - `GetVersion` with the app version
    /// - `GetLang` with the device locale
    ///
    /// - SeeAlso: ``getLang()``, ``getVersion()``
    open func getLangVersion() {
        let myVersion = getVersion()
        let myLang = getLang()
        self.appEventWithDetails(eventString: "GetVersion", jsonDetails: "'version':'\(myVersion)'")
        self.appEventWithDetails(eventString: "GetLang", jsonDetails: "'language':'\(myLang)'")
    }

    // MARK: - StoreKit

    /// Fetches available products from App Store Connect.
    ///
    /// Loads the product specified by ``productID`` and populates the ``products`` array.
    /// Dispatches either `ProductsLoaded` or `ProductsLoadError` to JavaScript upon completion.
    ///
    /// - Note: Called automatically during initialization if a product ID is configured.
    public func loadSubscriptionOptions() async {
        do {
            let appProducts = try await Product.products(for: [productID])
            products = appProducts
            appEvent(eventString: "ProductsLoaded")
        } catch {
            appEvent(eventString: "ProductsLoadError")
        }
    }

    /// Initiates the purchase flow for the first available product.
    ///
    /// Requires ``uuidString`` to be set before calling. The UUID is passed as an
    /// App Account Token to link the transaction to a specific user account.
    ///
    /// ## Events Dispatched
    ///
    /// - `PurchaseTappedNoUUID`: Called if ``uuidString`` is empty
    /// - `PurchaseTappedGetProduct`: Purchase initiated
    /// - `PurchaseComplete`: Transaction verified and finished
    /// - `PurchaseFailed`: Transaction verification failed
    /// - `PurchaseSheetClosed`: User cancelled the purchase
    /// - `PurchasePending`: Purchase requires additional action
    /// - `PurchaseErrorUnknown`: An error occurred during purchase
    /// - `PurchaseNoProductsAvailable`: No products loaded in ``products``
    ///
    /// - Warning: Ensure ``uuidString`` is set before invoking this method.
    /// - SeeAlso: ``loadSubscriptionOptions()``
    public func purchaseTapped() {
        if uuidString == "" {
            appEvent(eventString: "PurchaseTappedNoUUID")
            return
        }

        if self.products.count > 0 {
            showActivity()
            Task { () -> Void in
                do {
                    appEvent(eventString: "PurchaseTappedGetProduct")

                    let result = try await self.products[0].purchase(options: [
                        .appAccountToken(UUID(uuidString: self.uuidString)!)
                    ])

                    switch result {
                    case .success(let verification):
                        switch verification {
                        case .verified(let transaction):
                            await transaction.finish()
                            hideActivity()
                            appEvent(eventString: "PurchaseComplete")

                        case .unverified:
                            hideActivity()
                            appEvent(eventString: "PurchaseFailed")
                        }
                    case .userCancelled:
                        hideActivity()
                        appEvent(eventString: "PurchaseSheetClosed")
                    case .pending:
                        hideActivity()
                        appEvent(eventString: "PurchasePending")
                    @unknown default:
                        assertionFailure("Purchase Unexpected result")
                        hideActivity()
                        appEvent(eventString: "PurchaseErrorUnknown")
                    }

                } catch {
                    hideActivity()
                    appEvent(eventString: "PurchaseErrorUnknown")
                    DispatchQueue.main.async {
                        let alertController = UIAlertController(title: "ERROR", message: error.localizedDescription, preferredStyle: .alert)
                        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alertController.addAction(defaultAction)
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
        } else {
            appEvent(eventString: "PurchaseNoProductsAvailable")
            DispatchQueue.main.async {
                let alertController = UIAlertController(title: "No Products Available", message: "", preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(defaultAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }

    /// Restores previously purchased transactions from the App Store.
    ///
    /// Calls `AppStore.sync()` to refresh the user's transaction history.
    ///
    /// - Returns: `true` if sync succeeded, `false` otherwise.
    func restore() async -> Bool {
        return ((try? await AppStore.sync()) != nil)
    }

    /// Creates a background task that listens for StoreKit transaction updates.
    ///
    /// Monitors `Transaction.updates` for incoming transactions and finishes them.
    /// Handles revocations, expirations, and upgrades by returning early.
    ///
    /// - Returns: A long-running task that processes transaction updates.
    private func updatesListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await verificationResult in Transaction.updates {
                guard case .verified(let transaction) = verificationResult else {
                    return
                }

                Task {
                    await transaction.finish()
                }

                if let revocationDate = transaction.revocationDate {
                    _ = revocationDate
                    return
                } else if let expirationDate = transaction.expirationDate,
                          expirationDate < Date() {
                    return
                } else if transaction.isUpgraded {
                    return
                } else {
                    return
                }
            }
        }
    }
}
