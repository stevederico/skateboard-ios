//
//  SKAppController.swift
//

import UIKit
@preconcurrency import WebKit
import StoreKit
import Network
import AVFoundation

open class SKAppController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate, UIScrollViewDelegate {

    open var products = [Product]()
    open var uuidString = ""
    open var lastURL = ""
    open var productID = AppConstants.SUBSCRIPTION_URL
    var updates: Task<Void, Never>? = nil
    open var webView = WKWebView()
    var activityView = UIView()
    var isActivityShowing = false

    public required init() {
        super.init(nibName: nil, bundle: nil)

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(self, name: "SKMessageHandler")

        webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        webView.uiDelegate = self

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

        self.loadURL(urlString: AppConstants.BASE_URL)

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
        return .darkContent
    }

    open override var prefersStatusBarHidden: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

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

    @objc open func loadURL(urlString: String) {
        self.lastURL = urlString

        DispatchQueue.main.async {
            let url = URL(string: urlString)!
            var request = URLRequest(url: url)
            request.setValue("SK-Browser", forHTTPHeaderField: "SK-Browser")
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            self.webView.load(request)
        }
    }

    // MARK: - JS Message Handler

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        var action = "none"
        let dic = message.body as? [String: String]
        if let actionUnwrapped = dic?["action"] {
            if action.count > 0 {
                action = actionUnwrapped
            }
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

    public func appEvent(eventString: String) {
        DispatchQueue.main.async {
            let script = "document.querySelector('#skhub').dispatchEvent( new CustomEvent('app-event', {'detail':  {'title': '\(eventString)'}}));"
            self.webView.evaluateJavaScript(script)
        }
    }

    public func appEventWithDetails(eventString: String, jsonDetails: String) {
        DispatchQueue.main.async {
            let script = "document.querySelector('#skhub').dispatchEvent( new CustomEvent('app-event', {'detail':  {'title': '\(eventString)', \(jsonDetails)}}));"
            self.webView.evaluateJavaScript(script)
        }
    }

    open func getLang() -> String {
        let locale = NSLocale.current.identifier
        return locale
    }

    open func getVersion() -> String {
        var versionString = "0.0"
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            versionString = version
        }
        return versionString
    }

    open func getLangVersion() {
        let myVersion = getVersion()
        let myLang = getLang()
        self.appEventWithDetails(eventString: "GetVersion", jsonDetails: "'version':'\(myVersion)'")
        self.appEventWithDetails(eventString: "GetLang", jsonDetails: "'language':'\(myLang)'")
    }

    // MARK: - StoreKit

    public func loadSubscriptionOptions() async {
        do {
            let appProducts = try await Product.products(for: [productID])
            products = appProducts
            appEvent(eventString: "ProductsLoaded")
        } catch {
            appEvent(eventString: "ProductsLoadError")
        }
    }

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

    func restore() async -> Bool {
        return ((try? await AppStore.sync()) != nil)
    }

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
