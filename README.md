# skateboard-ios 🛹
### Native iOS wrapper for web apps. 3 lines of config. Ship to the App Store.

<p align="center">
  <img src="https://github.com/user-attachments/assets/b7f2b098-503b-4439-8454-7eb45ae82307" alt="Skateboard iOS Banner" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/stevederico/skateboard/master/public/icons/icon.png" width="60" height="60" alt="Skateboard Logo">
</p>

<p align="center">
  <strong>Turn any web app into a native iOS app.</strong><br>
  StoreKit payments, native share sheets, and a JS-to-native bridge—without touching UIKit.
</p>

<p align="center">
  <a href="#requirements"><img src="https://img.shields.io/badge/iOS-15+-000000?style=flat&logo=apple" alt="iOS"></a>
  <a href="#requirements"><img src="https://img.shields.io/badge/Swift-5.9-FA7343?style=flat&logo=swift&logoColor=white" alt="Swift"></a>
  <a href="#requirements"><img src="https://img.shields.io/badge/Xcode-15+-147EFB?style=flat&logo=xcode&logoColor=white" alt="Xcode"></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-MIT-blue?style=flat" alt="License"></a>
</p>

<p align="center">
  <a href="#features"><img src="https://img.shields.io/badge/StoreKit-2-green" alt="StoreKit 2"></a>
  <a href="#features"><img src="https://img.shields.io/badge/iPhone%20%2B%20iPad-Universal-purple" alt="Universal"></a>
  <a href="#features"><img src="https://img.shields.io/badge/WebView-WKWebView-orange" alt="WKWebView"></a>
</p>

<p align="center">
  <a href="https://github.com/stevederico/skateboard">skateboard</a> •
  <a href="https://github.com/stevederico/skateboard-ui">skateboard-ui</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#js-bridge-api">JS Bridge</a>
</p>

## Table of Contents

- [Why skateboard-ios?](#why-skateboard-ios)
- [The Skateboard Ecosystem](#the-skateboard-ecosystem)
- [Quick Start](#quick-start)
- [Features](#features)
- [Architecture](#architecture)
- [JS Bridge API](#js-bridge-api)
- [Detecting Native Context](#detecting-native-context)
- [App Store Deployment](#app-store-deployment)
- [Building from Source](#building-from-source)
- [Requirements](#requirements)
- [Contributing](#contributing)
- [Related Projects](#related-projects)
- [License](#license)

## Why skateboard-ios?

You've built a beautiful web app. Now you want it in the App Store. The traditional path? Learn Swift, UIKit, SwiftUI, deal with app architecture, figure out StoreKit... weeks of work before you ship.

**skateboard-ios changes that.**

- **3 lines of config** — Set your App Store ID, subscription URL, and web app URL. Done.
- **StoreKit 2 built-in** — Subscriptions, one-time purchases, restore purchases—all handled.
- **JS Bridge included** — Call native APIs from JavaScript. Show share sheets, trigger reviews, manage purchases.
- **No UIKit required** — Your web app IS your UI. The native shell just wraps it.

Build with [skateboard](https://github.com/stevederico/skateboard) or [skateboard-ui](https://github.com/stevederico/skateboard-ui), then ship to iOS with skateboard-ios.

## The Skateboard Ecosystem

| Project | Platform | Purpose |
|---------|----------|---------|
| [skateboard](https://github.com/stevederico/skateboard) | Web | Full-stack React starter with auth, Stripe payments, Hono backend |
| [skateboard-ui](https://github.com/stevederico/skateboard-ui) | Web | React component library with 51+ shadcn/ui components, routing, layouts |
| **skateboard-ios** | iOS | Native shell to wrap skateboard web apps for the App Store |

## Quick Start

### 1. Clone & Open

```bash
git clone https://github.com/stevederico/skateboard-ios.git
cd skateboard-ios
open Skateboard.xcodeproj
```

### 2. Configure

Edit `AppConstants.swift` with your values:

```swift
struct AppConstants {
    static let APP_STORE_ID = "123456789"
    static let SUBSCRIPTION_URL = "com.yourcompany.app.subscription"
    static let APP_URL = "https://your-webapp.com"
}
```

### 3. Build & Run

Press `Cmd + R` in Xcode. That's it.

### 4. Customize (Optional)

Override `AppController.viewDidLoad()` for custom setup:

```swift
public class AppController: SKAppController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Your custom setup
    }
}
```

## Features

- **3-line AppDelegate** — Extend `SKAppDelegate` and you're done
- **Shell + Content** — Native shell wraps your web app, you focus on the product
- **StoreKit 2** — Subscriptions, purchases, restore—handled
- **JS Bridge** — Call native APIs from your web app via `postMessage`
- **Convention over config** — Set 3 constants, ship it
- **Universal** — iPhone and iPad, one codebase

## Architecture

skateboard-ios follows a simple shell architecture:

```
App/
├── AppDelegate.swift      # Your 3-line entry point
├── AppController.swift    # Optional customization hook
├── AppConstants.swift     # 3 values to configure
└── Library/
    ├── SKAppDelegate.swift    # Shell delegate (don't touch)
    └── SKAppController.swift  # WebView + StoreKit (don't touch)
```

### How It Works

1. **SKAppDelegate** — Handles app lifecycle, creates the window, loads your controller
2. **SKAppController** — Manages WKWebView, StoreKit 2, and the JS bridge
3. **AppConstants** — Your configuration. Three values. That's the entire setup.

The `Library/` folder contains the shell framework. You extend it, never modify it.

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

### Events Emitted

| Event | Payload | When |
|-------|---------|------|
| `ProductsLoaded` | — | StoreKit products ready |
| `PurchaseComplete` | — | Successful purchase |
| `PurchaseFailed` | — | Purchase verification failed |
| `PurchaseSheetClosed` | — | User cancelled purchase |
| `PurchasePending` | — | Purchase awaiting approval |
| `GetVersion` | `version` | App version string |
| `GetLang` | `language` | Device locale |

## Detecting Native Context

The WebView sends `SK-Browser: SK-Browser` on all requests. Use this to detect native context:

```javascript
// Server-side detection
if (req.headers['sk-browser']) {
    // Running in native shell
}
```

```javascript
// Client-side detection
const isNative = navigator.userAgent.includes('SK-Browser');
```

## App Store Deployment

1. Update `AppConstants.swift` with production values
2. Add your app icon to `Assets.xcassets/AppIcon.appiconset`
3. Configure signing in Xcode (Team, Bundle ID)
4. Set version and build number
5. Archive: `Product → Archive`
6. Upload to App Store Connect

### App Store Checklist

- [ ] App icon (1024x1024)
- [ ] Screenshots for all device sizes
- [ ] Privacy policy URL
- [ ] App Store description
- [ ] Keywords
- [ ] Support URL

## Building from Source

### Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15+
- Apple Developer account (for device testing and App Store)

### Build Steps

```bash
# Clone the repository
git clone https://github.com/stevederico/skateboard-ios.git
cd skateboard-ios

# Open in Xcode
open Skateboard.xcodeproj

# Select your target device/simulator
# Build: Cmd + B
# Run: Cmd + R
```

### Code Signing

For device testing or App Store deployment:

1. Open project settings in Xcode
2. Select your Team under "Signing & Capabilities"
3. Update Bundle Identifier to your own (e.g., `com.yourcompany.yourapp`)
4. Xcode will handle provisioning profiles automatically

## Requirements

- iOS 15+
- Xcode 15+
- Swift 5.9+
- macOS 14.0+ (for development)

## Contributing

We welcome contributions! Here's how:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Submit a pull request

### Development Guidelines

- Follow existing code style
- Test on both iPhone and iPad simulators
- Ensure StoreKit sandbox testing works
- Update documentation for API changes

## Related Projects

- [skateboard](https://github.com/stevederico/skateboard) — Full-stack React starter template
- [skateboard-ui](https://github.com/stevederico/skateboard-ui) — React component library

## License

MIT License. See [LICENSE](LICENSE) for details.

---

**Ready to ship?** Clone the repo, set 3 values, and submit to the App Store.
