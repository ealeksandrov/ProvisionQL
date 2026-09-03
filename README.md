# ProvisionQL

[![Build](https://github.com/ealeksandrov/ProvisionQL/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/ealeksandrov/ProvisionQL/actions/workflows/test.yml)
[![Latest Release](https://img.shields.io/github/release/ealeksandrov/ProvisionQL.svg)](https://github.com/ealeksandrov/ProvisionQL/releases/latest)
[![License](https://img.shields.io/github/license/ealeksandrov/ProvisionQL.svg)](LICENSE.md)
![Platform](https://img.shields.io/badge/platform-macOS%2015+-lightgrey.svg)

ProvisionQL is a macOS file inspector and Quick Look extension for Apple app archives and provisioning profiles.

Open or drop a supported file into the app for the full inspector, or use Finder Quick Look for previews and thumbnails.

## Supported Files

| File | Description |
| --- | --- |
| `.ipa` | Packaged iOS, tvOS, watchOS, or visionOS app |
| `.tipa` | TrollStore IPA |
| `.xcarchive` | Xcode archive, including macOS archive layouts |
| `.appex` | App extension bundle |
| `.mobileprovision` | iOS provisioning profile |
| `.provisionprofile` | macOS provisioning profile |

## Features

* App archive previews with bundle metadata, icon, entitlements, embedded provisioning profile, and diagnostics.
* Provisioning profile previews with type, platform, signature status, certificates, devices, entitlements, and validation diagnostics.
* Quick Look thumbnails for app archives and provisioning profiles.
* In-app file inspector for drag-and-drop and Open With workflows.
* In-preview error reporting for malformed profiles and archives.

## Installation

### Via Homebrew

```bash
brew install --cask provisionql
```

---

### Manual Installation

1. Download the latest `ProvisionQL.dmg` from [Releases](https://github.com/ealeksandrov/ProvisionQL/releases/latest).
2. Open the DMG and drag `ProvisionQL.app` to your `/Applications` folder.

---

### Post-Installation Setup (Required)

1. Launch `ProvisionQL.app` at least once to register the app-bundled extensions.
2. If Finder previews do not appear immediately, you need to enable them manually:
   - Click button "Open Settings" in `ProvisionQL.app` toolbar or go to **System Settings > Login Items & Extensions**.
   - Scroll down to the **Extensions** section.
   - Click **Quick Look** (or **Finder**) and ensure **ProvisionQL** is turned on.

## Development

Open `ProvisionQL.xcodeproj` in Xcode 26 or newer.

Useful commands:

```sh
swift test --package-path ProvisionQLCore
mise run lint
mise run format
```

## Author

Created and maintained by Evgeny Aleksandrov ([@ealeksandrov](https://x.com/ealeksandrov)).

### Acknowledgments

Initially based on [Provisioning by Craig Hockenberry](https://github.com/chockenberry/Provisioning).

## License

`ProvisionQL` is available under the MIT license. See [LICENSE.md](LICENSE.md) and the [privacy policy](PRIVACY.md).
