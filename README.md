#ProvisionQL - Quick Look for ipa & provision

![Thumbnails example](https://raw.github.com/ealeksandrov/ProvisionQL/master/Screenshots/1.png)

Inspired by number of existing alternatives, the goal of this project is to provide clean, reliable, current and open-source Quick Look plugin for iOS & OSX developers.

Thumbnails will show app icon for `.ipa` or expiring status and device count for `.mobileprovision`. Quick look preview will give a lot of information, including UUIDs, devices, certificates and much more.

Supporting file types:

* `.ipa` - iOS packaged application
* `.app` - iOS application bundle
* `.mobileprovision` - iOS provisioning profile
* `.provisionprofile` - OSX provisioning profile

[More screenshots](https://github.com/ealeksandrov/ProvisionQL/blob/master/screenshots.md)

License: MIT.

###Acknowledgments

Check out this great alternatives:

* [Provisioning by Craig Hockenberry](https://github.com/chockenberry/Provisioning)
* [ipaql by Rico Becker](http://ipaql.com/)


##Installation from Xcode project

Just clone the repository, open `ProvisionQL.xcodeproj` and build active target. Shell script will place generator in `~/Library/QuickLook` and call `qlmanage -r` automatically.


##Manual installation

* Download archive with latest version from the [Releases](https://github.com/ealeksandrov/ProvisionQL/releases) page.
* Move `ProvisionQL.qlgenerator` to `~/Library/QuickLook/`(current user) or `/Library/QuickLook/`(all users).
* run `qlmanage -r` to refresh Quick Look plugins list.
