#ProvisionQL - Quick Look for ipa & provision

![Thumbnails example](https://raw.github.com/ealeksandrov/ProvisionQL/master/Screenshots/1.png)

Inspired by number of existing alternatives, the goal of this project is to provide clean, reliable, current and open-source Quick Look plugin for iOS & OSX developers.

Thumbnails will show app icon for `.ipa` or expiring status and device count for `.mobileprovision`. Quick look preview will give a lot of information, including UUIDs, devices, certificates and much more.

Supporting file types:

* `.ipa` - iOS packaged application
* `.app` - iOS application bundle
* `.appex` - iOS/OSX application extension
* `.mobileprovision` - iOS provisioning profile
* `.provisionprofile` - OSX provisioning profile

[More screenshots](https://github.com/ealeksandrov/ProvisionQL/blob/master/screenshots.md)

License: MIT.

###Acknowledgments

Check out these great alternatives:

* [Provisioning by Craig Hockenberry](https://github.com/chockenberry/Provisioning)
* [ipaql by Rico Becker](http://ipaql.com/)

###Tutorials based on this example:

* english - [aleksandrov.ws](https://aleksandrov.ws/2014/02/25/osx-quick-look-plugin-development/)
* russian - [habrahabr.ru](http://habrahabr.ru/post/208552/)

##Installation from Homebrew Cask

[Homebrew cask](http://caskroom.io/) is the easiest way to install binary applications and quicklook plugins.
If you have [homebrew](http://brew.sh/) - use 3 lines below and you are ready.

```
# Cask install
brew tap caskroom/cask
brew install brew-cask

# ProvisionQL install
brew cask install provisionql
```

##Installation from Xcode project

Just clone the repository, open `ProvisionQL.xcodeproj` and build active target. Shell script will place generator in `~/Library/QuickLook` and call `qlmanage -r` automatically.


##Manual installation

* Download archive with latest version from the [Releases](https://github.com/ealeksandrov/ProvisionQL/releases) page.
* Move `ProvisionQL.qlgenerator` to `~/Library/QuickLook/`(current user) or `/Library/QuickLook/`(all users).
* run `qlmanage -r` to refresh Quick Look plugins list.
