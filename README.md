# skateboard-ios

![iOS](https://img.shields.io/badge/iOS-15+-000000?style=flat&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=flat&logo=swift&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat)

**Native iOS shell for skateboard web apps. 3 lines of config. Ship to the App Store.**

Turn any skateboard web app into a native iOS app with StoreKit payments, native share sheets, and a JS-to-native bridge—without touching UIKit.

## Features

- **3-line AppDelegate** — Extend `SKAppDelegate` and you're done
- **Shell + Content** — Native shell wraps your web app, you focus on the product
- **StoreKit 2** — Subscriptions, purchases, restore—handled
- **JS Bridge** — Call native APIs from your web app via `postMessage`
- **Convention over config** — Set 3 constants, ship it
- **Universal** — iPhone and iPad, one codebase

## Project Structure

```
App/
├── AppDelegate.swift      # Your 3-line entry point
├── AppController.swift    # Optional customization hook
├── AppConstants.swift     # 3 values to configure
└── Library/
    ├── SKAppDelegate.swift    # Shell delegate (don't touch)
    └── SKAppController.swift  # WebView + StoreKit (don't touch)
```

## Getting Started

### 1. Configure

Edit `AppConstants.swift`:

```swift
struct AppConstants {
    static let APP_STORE_ID = "123456789"
    static let SUBSCRIPTION_URL = "com.yourcompany.app.subscription"
    static let APP_URL = "https://your-webapp.com"
}
```

### 2. Build

Open `Skateboard.xcodeproj` in Xcode. Build and run.

### 3. Customize (Optional)

Override `AppController.viewDidLoad()` for custom setup:

```swift
public class AppController: SKAppController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Your custom setup
    }
}
```

## JS Bridge API

Post messages to `SKMessageHandler` from your web app:

```javascript
window.webkit.messageHandlers.SKMessageHandler.postMessage({
    action: 'actionName',
    // ...params
});
```

### Available Actions

| Action | Params | Description |
|--------|--------|-------------|
| `showShare` | `appid` | Native share sheet with App Store link |
| `showRate` | `appid` | Opens App Store review prompt |
| `restorePurchases` | — | Restores previous purchases |
| `purchaseTapped` | `uuid` | Initiates StoreKit purchase flow |
| `getPID` | `subscriptionURL` | Loads a different product ID |
| `showActivity` | — | Shows native loading spinner |
| `hideActivity` | — | Hides loading spinner |
| `userReady` | — | Triggers version/language sync |

### Receiving Events

Listen for native events on `#skhub`:

```javascript
document.querySelector('#skhub').addEventListener('app-event', (e) => {
    console.log(e.detail.title); // Event name
    console.log(e.detail);       // Full payload
});
```

#### Events Emitted

| Event | Payload | When |
|-------|---------|------|
| `ProductsLoaded` | — | StoreKit products ready |
| `PurchaseComplete` | — | Successful purchase |
| `PurchaseFailed` | — | Purchase verification failed |
| `PurchaseSheetClosed` | — | User cancelled purchase |
| `PurchasePending` | — | Purchase awaiting approval |
| `GetVersion` | `version` | App version string |
| `GetLang` | `language` | Device locale |

## Request Header

The WebView sends `SK-Browser: SK-Browser` on all requests. Use this to detect native context:

```javascript
// Server-side detection
if (req.headers['sk-browser']) {
    // Running in native shell
}
```

## App Store Deployment

1. Update `AppConstants.swift` with production values
2. Add your app icon to `Assets.xcassets/AppIcon.appiconset`
3. Configure signing in Xcode
4. Archive and upload to App Store Connect

## Requirements

- iOS 15+
- Xcode 15+
- Swift 5.9+

## License

MIT
