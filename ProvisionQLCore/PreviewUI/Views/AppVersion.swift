//
//  AppVersion.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import Foundation

enum AppVersion {
    /// Returns the formatted version string for the app (e.g., "v1.0.0 (123)")
    static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "v\(version) (\(build))"
    }
}
