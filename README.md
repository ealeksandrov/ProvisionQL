# ProvisionQL - Quick Look for ipa & provision

[![CI Status](http://img.shields.io/travis/ealeksandrov/ProvisionQL.svg)](https://travis-ci.org/ealeksandrov/ProvisionQL)
[![Latest Release](https://img.shields.io/github/release/ealeksandrov/ProvisionQL.svg)](https://github.com/ealeksandrov/ProvisionQL/releases/latest)
[![License](https://img.shields.io/github/license/ealeksandrov/ProvisionQL.svg)](LICENSE.md)
![Platform](https://img.shields.io/badge/platform-macos-lightgrey.svg)

![Thumbnails example](https://raw.github.com/ealeksandrov/ProvisionQL/master/Screenshots/1.png)

Inspired by number of existing alternatives, the goal of this project is to provide clean, reliable, current and open-source Quick Look plugin for iOS & OSX developers.

Thumbnails will show app icon for `.ipa`/ `.xcarchive` or expiring status and device count for `.mobileprovision`. Quick look preview will give a lot of information, including devices UUIDs, certificates, entitlements and much more.

![Valid AdHoc provision](https://raw.github.com/ealeksandrov/ProvisionQL/master/Screenshots/2.png)

Supporting file types:

* `.ipa` - iOS packaged application
* `.xcarchive` - Xcode archive
* `.appex` - iOS/OSX application extension
* `.mobileprovision` - iOS provisioning profile
* `.provisionprofile` - OSX provisioning profile

[More screenshots](https://github.com/ealeksandrov/ProvisionQL/blob/master/Screenshots/README.md)

### Acknowledgments

Initially based on [Provisioning by Craig Hockenberry](https://github.com/chockenberry/Provisioning).

### Tutorials based on this example:

* english - [aleksandrov.ws](https://aleksandrov.ws/2014/02/25/osx-quick-look-plugin-development/)
* russian - [habrahabr.ru](http://habrahabr.ru/post/208552/)

## Installation

### Homebrew Cask

[Homebrew cask](http://caskroom.io/) is the easiest way to install binary applications and quicklook plugins. If you have [homebrew](http://brew.sh/) - use the line below and you are ready.

```sh
brew cask install provisionql
```

### Xcode project

Just clone the repository, open `ProvisionQL.xcodeproj` and build active target. Shell script will place generator in `~/Library/QuickLook` and call `qlmanage -r` automatically.

### Manual

* Download archive with latest version from the [Releases](https://github.com/ealeksandrov/ProvisionQL/releases/latest) page;
* move `ProvisionQL.qlgenerator` to `~/Library/QuickLook/`(current user) or `/Library/QuickLook/`(all users);
* run `qlmanage -r` to refresh Quick Look plugins list.

## Author

Created and maintained by Evgeny Aleksandrov ([@EAleksandrov](https://twitter.com/EAleksandrov)).

## License

`ProvisionQL` is available under the MIT license. See the [LICENSE.md](LICENSE.md) file for more info.
