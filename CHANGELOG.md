# ProvisionQL

## Version 1.7.0

* New: show iTunes Metadata & purchase information
* New: use higher resolution app icon if available (try `iTunesArtwork`)
* New: show entitlements regardless of provisioning plist if available
* New: load icon from `Assets.car`
* Performance: unzip with zlib instead of sys-call
* Performance: parse html template tags with regex
* Performance: use `SecCodeSigning` instead of `codesign` sys-call
* Fix codesign unkown param on <10.15 (`--xml` flag)
* Fix crash if a plist key is not present (e.g. `CFBundleShortVersionString` for some old iOS 3.2 ipa)
* Fix fixed-width size for preview of app-icon (consistency)
* Fix `IconFlavor` attribute for thumbnail drawing in 10.15+
* Fix prefer icons without "small" suffix
* Minor html template improvements
* Some refactoring to reduce duplicate code

## Version 1.6.4

* Adds error handling to entitlements parsing ([#47](https://github.com/ealeksandrov/ProvisionQL/pull/47))

## Version 1.6.3

* Improves app extensions (`.appex`) support ([#45](https://github.com/ealeksandrov/ProvisionQL/pull/45))

## Version 1.6.2

* Adds XML escaping for file name ([#36](https://github.com/ealeksandrov/ProvisionQL/issues/36))
* Improves relative date intervals formatting ([#35](https://github.com/ealeksandrov/ProvisionQL/issues/35))
* Moves entitlements higher in preview ([#31](https://github.com/ealeksandrov/ProvisionQL/issues/31))

## Version 1.6.1

* Adds code signing, fixes macOS Catalina compatibility ([#30](https://github.com/ealeksandrov/ProvisionQL/issues/30))

## Version 1.6.0

* Adds dark mode support ([#29](https://github.com/ealeksandrov/ProvisionQL/pull/29))

## Version 1.5.0

* Fixes missing icons for iPad-only apps ([#8](https://github.com/ealeksandrov/ProvisionQL/issues/22))
* Improves icons parsing and extraction

## Version 1.4.1

* Fixes Quick Look timeout in some cases ([#8](https://github.com/ealeksandrov/ProvisionQL/issues/8))

## Version 1.4.0

* Adds parsing code signing entitlements from the application binary ([#16](https://github.com/ealeksandrov/ProvisionQL/pull/16) and [#3](https://github.com/ealeksandrov/ProvisionQL/issues/3))
* Adds xcarchives support (`.xcarchive`) ([#10](https://github.com/ealeksandrov/ProvisionQL/issues/10))
* Removes Xcode devices data and related formatting ([#9](https://github.com/ealeksandrov/ProvisionQL/issues/9))
* Removes application-bundle (`.app`) support ([#14](https://github.com/ealeksandrov/ProvisionQL/issues/14))
* Fixes expiration status calculation ([#17](https://github.com/ealeksandrov/ProvisionQL/issues/17))
* Fixes icons "IconFlavor" for apps thumbnails ([#2](https://github.com/ealeksandrov/ProvisionQL/issues/2))
* Fixes wrong thumnails and previews for bundles with multiple plugin executables
* Improves app preview layout
* Improves App Transport Security section formatting

## Version 1.3.0
* Adds NSAppTransportSecurity, DTSDKName, and MinimumOSVersion ([#7](https://github.com/ealeksandrov/ProvisionQL/pull/7)

## Version 1.2.0
* Adds support for app extensions (`.appex`)

## Version 1.1.0
* Adds support  for new Xcode 6 projects ([#6](https://github.com/ealeksandrov/ProvisionQL/pull/6) and [#5](https://github.com/ealeksandrov/ProvisionQL/issues/5))

## Version 1.0.0
* Initial release
