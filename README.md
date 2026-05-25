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

1. Download the latest release from [Releases](https://github.com/ealeksandrov/ProvisionQL/releases/latest).
2. Unzip the archive and move `ProvisionQL.app` to `/Applications`.
3. Launch `ProvisionQL.app` once.
4. If Finder previews do not appear, enable the Quick Look extensions in System Settings > Login Items & Extensions.

From the toolbar, click Extensions to open System Settings > Login Items & Extensions.

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

`ProvisionQL` is available under the MIT license. See [LICENSE.md](LICENSE.md) for details.
